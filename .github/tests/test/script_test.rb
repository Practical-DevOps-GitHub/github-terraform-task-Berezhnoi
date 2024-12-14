require 'test/unit'
require 'json' # For pretty JSON formatting
require_relative '../src/script'

class ScriptTest < Test::Unit::TestCase

  def setup
    url = ENV['URL'].nil? ? '' : ENV["URL"]
    token = ENV['TOKEN'].nil? ? '' : ENV["TOKEN"]
    @secrets_token = ENV['SECRETS_TOKEN']
    @obj = GithubApi.new(url, token)
  end

  # Helper method to log data as JSON
  def log_data(data, label = "Data")
    puts "\n=== #{label} ==="
    puts JSON.pretty_generate(data)
    puts "=================\n"
  rescue => e
    puts "\nError logging data: #{e.message}"
  end

  def test_health_check
    repo_uri = @obj.instance_variable_get('@repo_uri')
    token = @obj.instance_variable_get('@token')
    log_data({ repo_uri: repo_uri, token: token }, "Health Check Data")
    assert_not_nil(repo_uri, 'Url alive')
    assert_not_nil(token, 'Token alive')
  end
  
  def test_token_present
    actual = @secrets_token =~ /^ghp_\w{36}$/
    log_data({ secrets_token: @secrets_token }, "Token Validation")
    assert_not_nil(actual, "Secret with name 'PAT' with valid personal access token doesn't exist")
  end

  def test_deploy_key_present
    response = @obj.deploy_keys
    log_data(response, "Deploy Keys Response")
    assert_not_nil(response, "Access denied")
    deploy_key = response.find { |element| element['title'] == 'DEPLOY_KEY' }
    assert_not_nil(deploy_key, "The deploy key with name 'DEPLOY_KEY' doesn't exist")
  end

  def test_main_present
    actual = @obj.branch_exist?('main')
    log_data({ main_branch_exists: actual }, "Main Branch Existence")
    assert(actual, 'Branch main is not present')
  end

  def test_main_protected
    actual = @obj.branch_protected?('main')
    log_data({ main_branch_protected: actual }, "Main Branch Protection")
    assert(actual, 'Branch main is not protected')
  end

  def test_develop_present
    actual = @obj.branch_exist?('develop')
    log_data({ develop_branch_exists: actual }, "Develop Branch Existence")
    assert(actual, 'Branch develop is not present')
  end

  def test_develop_protected
    actual = @obj.branch_protected?('develop')
    log_data({ develop_branch_protected: actual }, "Develop Branch Protection")
    assert(actual, 'Branch develop is not protected')
  end

  def test_develop_default
    actual = @obj.default_branch
    expected = 'develop'
    log_data({ default_branch: actual }, "Default Branch Validation")
    assert_equal(expected, actual, 'Default branch isn\'t develop')
  end

  def test_codeowners_contains_user
    user_name = 'softservedata'
    content = @obj.file_branch('CODEOWNERS', 'main') || @obj.file_branch('.github/CODEOWNERS', 'main') || @obj.file_branch('docs/CODEOWNERS', 'main')
    log_data({ codeowners_content: content }, "CODEOWNERS Content")
    assert_not_nil(content, 'File CODEOWNERS doesn\'t exist on main branch')
    assert(content.include?(user_name), "User #{user_name} doesn't present in CODEOWNERS")
  end

  def test_codeowners_not_present_develop
    content = @obj.file_branch('CODEOWNERS', 'develop')
    log_data({ develop_codeowners_content: content }, "Develop Branch CODEOWNERS")
    assert_nil(content, 'File CODEOWNERS exists on develop branch')
  end

  def test_deny_merge_main
    actual = @obj.rules_required_pull_request_reviews('main')
    log_data(actual, "Main Branch Merge Rules")
    assert_not_nil(actual, 'We should not allow merge to main branch without PR')
  end

  def test_deny_merge_develop
    actual = @obj.rules_required_pull_request_reviews('develop')
    log_data(actual, "Develop Branch Merge Rules")
    assert_not_nil(actual, 'We should not allow merge to develop branch without PR ')
  end

  def test_2_approvals_develop
    actual = @obj.rules_required_pull_request_reviews('develop').nil? || @obj.rules_required_pull_request_reviews('develop')["required_approving_review_count"]
    expected = 2
    log_data({ required_approvals: actual }, "Develop Branch Approval Rules")
    assert_equal(expected, actual, 'We should have 2 approvals before merge to develop branch')
  end

  def test_without_approval_main
    actual = @obj.rules_required_pull_request_reviews('main').nil? || @obj.rules_required_pull_request_reviews('main')["required_approving_review_count"]
    expected = 0
    log_data({ required_approvals: actual }, "Main Branch Approval Rules")
    assert_equal(expected, actual, 'We shouldn\'t have any approvals before merge to main branch')
  end

  def test_approve_from_user
    user_name = 'online-marathon'
    actual = @obj.rules_required_pull_request_reviews('develop').nil? || @obj.rules_required_pull_request_reviews('develop')["require_code_owner_reviews"]
    log_data({ code_owner_reviews_required: actual }, "Approval Rules for #{user_name}")
    assert_not_nil(actual, "We should not allow merge to develop branch without approval from #{user_name}")
  end

  def test_PR_template_present
    actual = @obj.file_branch('.github/pull_request_template.md', 'main')
    log_data({ pull_request_template: actual }, "Pull Request Template Content")
    assert_not_nil(actual, 'Pull request template is absent')
  end

end
