#!/usr/bin/env ruby
# frozen_string_literal: true
#
# ios/Runner.xcodeproj に DoLimitWidget（WidgetKit 拡張）ターゲットを追加する。
# - 冪等: 既に DoLimitWidget があれば作成をスキップ（フェーズ順の調整は毎回行う）。
# - App Group(group.dolimit.widget) を Runner / Widget の両方に付与。
# - バージョンは add_ios_widget.sh が Info.plist に直接焼き込むため、ここでは扱わない。
# - "Cycle inside Runner" 回避のため Embed App Extensions を必ず最後のフェーズにする。
#   （その前に pod install 済みで [CP] フェーズが存在している前提。add_ios_widget.sh が担保）
#
# 依存: xcodeproj gem（CocoaPods 同梱）。

require 'xcodeproj'

APP_BUNDLE_ID    = 'com.tmk4men.dolimit'
WIDGET_NAME      = 'DoLimitWidget'
WIDGET_BUNDLE_ID = "#{APP_BUNDLE_ID}.#{WIDGET_NAME}"
DEPLOY_TARGET    = '14.0' # WidgetKit の最低要件
TEAM_ID          = ENV['TEAM_ID'].to_s.strip

root         = File.expand_path('..', __dir__)
project_path = File.join(root, 'ios', 'Runner.xcodeproj')
abort("[add_ios_widget] ios/Runner.xcodeproj が見つかりません。先に flutter create を実行してください。") \
  unless File.directory?(project_path)

project = Xcodeproj::Project.open(project_path)
runner  = project.targets.find { |t| t.name == 'Runner' }
abort("[add_ios_widget] Runner ターゲットが見つかりません。") unless runner

widget = project.targets.find { |t| t.name == WIDGET_NAME }

unless widget
  # --- ターゲット作成 -------------------------------------------------------------
  widget = project.new_target(:app_extension, WIDGET_NAME, :ios, DEPLOY_TARGET, nil, :swift)

  group     = project.main_group.new_group(WIDGET_NAME, WIDGET_NAME)
  swift_ref = group.new_reference("#{WIDGET_NAME}.swift")
  group.new_reference('Info.plist')
  group.new_reference("#{WIDGET_NAME}.entitlements")
  widget.add_file_references([swift_ref])

  widget.build_configurations.each do |config|
    bs = config.build_settings
    bs['PRODUCT_BUNDLE_IDENTIFIER']  = WIDGET_BUNDLE_ID
    bs['PRODUCT_NAME']               = '$(TARGET_NAME)'
    bs['INFOPLIST_FILE']             = "#{WIDGET_NAME}/Info.plist"
    bs['CODE_SIGN_ENTITLEMENTS']     = "#{WIDGET_NAME}/#{WIDGET_NAME}.entitlements"
    bs['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOY_TARGET
    bs['SWIFT_VERSION']              = '5.0'
    bs['TARGETED_DEVICE_FAMILY']     = '1,2'
    bs['GENERATE_INFOPLIST_FILE']    = 'NO'
    bs['CODE_SIGN_STYLE']            = 'Automatic'
    bs['SKIP_INSTALL']               = 'YES'
    bs['LD_RUNPATH_SEARCH_PATHS']    = ['$(inherited)', '@executable_path/Frameworks',
                                        '@executable_path/../../Frameworks']
    bs['DEVELOPMENT_TEAM'] = TEAM_ID unless TEAM_ID.empty?
  end

  # --- Runner に依存＆埋め込み ------------------------------------------------------
  runner.add_dependency(widget)
  embed = runner.copy_files_build_phases.find { |p| p.symbol_dst_subfolder_spec == :plug_ins }
  embed ||= runner.new_copy_files_build_phase('Embed App Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
  bf = embed.add_file_reference(widget.product_reference, true)
  bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

  # --- Runner にも App Group entitlements ------------------------------------------
  runner_group = project.main_group['Runner'] || project.main_group.new_group('Runner', 'Runner')
  unless runner_group.files.any? { |f| f.display_name == 'Runner.entitlements' }
    runner_group.new_reference('Runner.entitlements')
  end
  runner.build_configurations.each do |config|
    cur = config.build_settings['CODE_SIGN_ENTITLEMENTS']
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements' if cur.nil? || cur.to_s.strip.empty?
  end

  attrs = (project.root_object.attributes['TargetAttributes'] ||= {})
  attrs[widget.uuid] = { 'ProvisioningStyle' => 'Automatic' }
  if TEAM_ID.empty?
    team = runner.build_configurations.map { |c| c.build_settings['DEVELOPMENT_TEAM'] }.compact.first
    widget.build_configurations.each { |c| c.build_settings['DEVELOPMENT_TEAM'] = team } if team && !team.to_s.strip.empty?
  end

  puts "[add_ios_widget] #{WIDGET_NAME}(#{WIDGET_BUNDLE_ID}) を作成しました。"
else
  puts "[add_ios_widget] #{WIDGET_NAME} は既存。ビルドフェーズ順のみ調整します。"
end

# --- 既存ターゲットの掃除（前バージョンで付いた Generated.xcconfig 継承を除去）--------
# 版数は Info.plist 焼き込みに一本化したので、widget に Flutter の xcconfig は不要。
# 継承が残っていると Flutter のビルド設定を引き込んで循環の一因になり得るため必ず外す。
widget.build_configurations.each { |c| c.base_configuration_reference = nil }

# --- "Cycle inside Runner" 回避: Embed App Extensions を最後のフェーズへ移動 --------
# CocoaPods の [CP] Embed Pods Frameworks より後ろに置くと循環が切れる。
embed = runner.copy_files_build_phases.find { |p| p.symbol_dst_subfolder_spec == :plug_ins }
if embed
  runner.build_phases.delete(embed)
  runner.build_phases << embed
  puts '[add_ios_widget] Embed App Extensions を末尾へ移動（Cycle 回避）。'
end

project.save
puts '[add_ios_widget] 完了。'
