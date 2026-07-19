#!/usr/bin/env ruby
# frozen_string_literal: true
#
# ios/Runner.xcodeproj に DoLimitWidget（WidgetKit 拡張）ターゲットを追加する。
# - 冪等: 既に DoLimitWidget ターゲットがあれば何もしない。
# - App Group(group.dolimit.widget) を Runner / Widget の両方に付与。
# - バージョンは Flutter(Generated.xcconfig)に自動同期するので更新時も appex 版数がズレない。
#
# 呼び出し元: scripts/add_ios_widget.sh（先にソース/entitlements を ios/ 配下へ配置してから実行）。
# 依存: xcodeproj gem（CocoaPods に同梱。無ければ add_ios_widget.sh が入れる）。

require 'xcodeproj'

APP_BUNDLE_ID    = 'com.tmk4men.dolimit'
WIDGET_NAME      = 'DoLimitWidget'
WIDGET_BUNDLE_ID = "#{APP_BUNDLE_ID}.#{WIDGET_NAME}"
DEPLOY_TARGET    = '14.0' # WidgetKit の最低要件
TEAM_ID          = ENV['TEAM_ID'].to_s.strip # 任意: 指定すると Widget にも署名チームを設定

root         = File.expand_path('..', __dir__)
project_path = File.join(root, 'ios', 'Runner.xcodeproj')
abort("[add_ios_widget] ios/Runner.xcodeproj が見つかりません。先に flutter create を実行してください。") \
  unless File.directory?(project_path)

project = Xcodeproj::Project.open(project_path)

if project.targets.any? { |t| t.name == WIDGET_NAME }
  puts "[add_ios_widget] #{WIDGET_NAME} ターゲットは既に存在します。スキップ。"
  exit 0
end

runner = project.targets.find { |t| t.name == 'Runner' }
abort("[add_ios_widget] Runner ターゲットが見つかりません。") unless runner

# --- バージョンを Flutter に同期させるための Generated.xcconfig 参照 -----------------
# Runner の Debug/Release.xcconfig は Pods 設定も #include するため、それを継承すると
# ウィジェットに Runner の Pods がリンクされてしまう。バージョン変数(FLUTTER_BUILD_*)だけ
# 欲しいので Generated.xcconfig を直接ベース設定にする。
gen_ref = project.files.find { |f| (f.path || '').end_with?('Generated.xcconfig') }
gen_ref ||= project.main_group.new_file('Flutter/Generated.xcconfig')

# --- ターゲット作成 ---------------------------------------------------------------
widget = project.new_target(:app_extension, WIDGET_NAME, :ios, DEPLOY_TARGET, nil, :swift)

# --- グループとファイル参照（実ファイルは add_ios_widget.sh が配置済み）-------------
group     = project.main_group.new_group(WIDGET_NAME, WIDGET_NAME)
swift_ref = group.new_reference("#{WIDGET_NAME}.swift")
group.new_reference('Info.plist')
group.new_reference("#{WIDGET_NAME}.entitlements")
widget.add_file_references([swift_ref])

# --- ビルド設定 -------------------------------------------------------------------
widget.build_configurations.each do |config|
  bs = config.build_settings
  bs['PRODUCT_BUNDLE_IDENTIFIER'] = WIDGET_BUNDLE_ID
  bs['PRODUCT_NAME']              = '$(TARGET_NAME)'
  bs['INFOPLIST_FILE']            = "#{WIDGET_NAME}/Info.plist"
  bs['CODE_SIGN_ENTITLEMENTS']    = "#{WIDGET_NAME}/#{WIDGET_NAME}.entitlements"
  bs['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOY_TARGET
  bs['SWIFT_VERSION']             = '5.0'
  bs['TARGETED_DEVICE_FAMILY']    = '1,2'
  bs['GENERATE_INFOPLIST_FILE']   = 'NO'
  bs['CODE_SIGN_STYLE']           = 'Automatic'
  bs['SKIP_INSTALL']              = 'YES'
  bs['CURRENT_PROJECT_VERSION']   = '$(FLUTTER_BUILD_NUMBER)'
  bs['MARKETING_VERSION']         = '$(FLUTTER_BUILD_NAME)'
  bs['LD_RUNPATH_SEARCH_PATHS']   = ['$(inherited)', '@executable_path/Frameworks',
                                     '@executable_path/../../Frameworks']
  bs['DEVELOPMENT_TEAM'] = TEAM_ID unless TEAM_ID.empty?
  config.base_configuration_reference = gen_ref
end

# --- Runner に依存＆埋め込み（Embed App Extensions）--------------------------------
runner.add_dependency(widget)
embed = runner.copy_files_build_phases.find { |p| p.symbol_dst_subfolder_spec == :plug_ins }
embed ||= runner.new_copy_files_build_phase('Embed App Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
build_file = embed.add_file_reference(widget.product_reference, true)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# --- Runner 側にも App Group entitlements を割り当て ------------------------------
runner_group = project.main_group['Runner'] || project.main_group.new_group('Runner', 'Runner')
unless runner_group.files.any? { |f| f.display_name == 'Runner.entitlements' }
  runner_group.new_reference('Runner.entitlements')
end
runner.build_configurations.each do |config|
  cur = config.build_settings['CODE_SIGN_ENTITLEMENTS']
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements' if cur.nil? || cur.to_s.strip.empty?
end

# --- 署名スタイルを Automatic に（プロビジョニング自動更新用）----------------------
attrs = (project.root_object.attributes['TargetAttributes'] ||= {})
attrs[widget.uuid] = { 'ProvisioningStyle' => 'Automatic' }
if TEAM_ID.empty?
  # チーム未指定なら Runner の既存チームを引き継ぐ（再実行時に有効）
  team = runner.build_configurations.map { |c| c.build_settings['DEVELOPMENT_TEAM'] }.compact.first
  if team && !team.to_s.strip.empty?
    widget.build_configurations.each { |c| c.build_settings['DEVELOPMENT_TEAM'] = team }
  end
end

project.save
puts "[add_ios_widget] #{WIDGET_NAME}(#{WIDGET_BUNDLE_ID}) を追加しました。"
