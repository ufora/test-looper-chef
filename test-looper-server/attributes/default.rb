default["test_looper_server"]["service_account"] = "test-looper"
default["test_looper_server"]["install_dir"] = "/opt/test-looper-server"
default["test_looper_server"]["ssl_dir"] = "/etc/apache2/ssl"

default["test_looper_server"]["ssl_cert_prefix"] = "ufora"
default["test_looper_server"]["dnsname"] = "test-looper.ufora.com"
default["test_looper_server"]["port"] = "7531"
default["test_looper_server"]["http_port"] = "8888"


default["test_looper_server"]["data_bag_bucket"] = "ufora-opsworks-us-west-2"
default["test_looper_server"]["data_bag_key"] = "test-looper/server.json"
default["test_looper_server"]["encrypted_data_bag_key"] = "Must be set as custom JSON in OpsWorks"

default["test_looper_server"]["git_ssh_wrapper"] = "wrap-ssh4git.sh"

default["test_looper_server"]["git_repo"] = "git@github.com:ufora/main.git"
default["test_looper_server"]["git_branch"] = "test-looper-2"
default["test_looper_server"]["github_deploy_key"] = "id_deploy"
default["test_looper_server"]["github_login"] = "ufora-bot"
default["test_looper_server"]["github_oauth_app_id"] = "eb57b8cf7f9122dad732"

default["test_looper_server"]["ec2_worker_security_group"] = "sg-06382863"
default["test_looper_server"]["ec2_worker_ami"] = "ami-5b0d346b"
default["test_looper_server"]["ec2_worker_role_name"] = "test-looper"
default["test_looper_server"]["ec2_worker_ssh_key_name"] = "test-looper"
default["test_looper_server"]["ec2_worker_root_volume_size_gb"] = "30"

default["test_looper_server"]["expected_dependencies_version"] = "7c69b38771e10af88e992cb2313becfc44e74dab"

default['apt']['compile_time_update'] = true



# TODO: figure out how to reference the test-looper cookbook
default["test_looper"]["install_dir"] = "/opt/test-looper"
default["test_looper"]["config_file"] = "test-looper.conf.json"
default["test_looper"]["ec2_test_result_bucket"] = "ufora-test-results-us-west-2"
default["test_looper"]["ec2_builds_bucket"] = "ufora-builds-us-west-2"
