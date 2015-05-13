default["test_looper"]["service_account"] = "test-looper"
default["test_looper"]["github_deploy_key"] = "id_deploy"
default["test_looper"]["test_looper_install_dir"] = "/opt/test-looper"

default["test_looper"]["git_ssh_wrapper"] = "wrap-ssh4git.sh"

default["test_looper"]["git_repo"] = "git@github.com:ufora/main.git"
default["test_looper"]["test_looper_git_branch"] = "test-looper-2"

default["test_looper"]["expected_dependencies_version"] = "7c69b38771e10af88e992cb2313becfc44e74dab"

default["test_looper"]["ec2_test_result_bucket"] = "ufora-test-results-us-west-2"
default["test_looper"]["ec2_test_result_bucket"] = "ufora-builds-us-west-2"
default['apt']['compile_time_update'] = true
