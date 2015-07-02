# Common Attributes
default["test_looper"]["service_account"] = "test-looper"
default["test_looper"]["home_dir"] = "/home/#{default["test_looper"]["service_account"]}"
default["test_looper"]["github_deploy_key"] = "id_deploy"
default["test_looper"]["git_ssh_wrapper"] = "wrap-ssh4git.sh"
default["test_looper"]["git_repo"] = "git@github.com:ufora/main.git"
default["test_looper"]["git_branch"] = "test-looper-2"

default["test_looper"]["data_bag_bucket"] = "ufora-opsworks-us-west-2"
default["test_looper"]["encrypted_data_bag_key"] = "Must be set as custom JSON in OpsWorks"

default["test_looper"]["environment"] = "prod"

default["test_looper"]["ec2_test_result_bucket"] = "ufora-test-results-us-west-2"
default["test_looper"]["ec2_builds_bucket"] = "ufora-builds-us-west-2"

# TODO: remove when using only shrink-wrapped packages
default["test_looper"]["expected_dependencies_version"] = "7c69b38771e10af88e992cb2313becfc44e74dab"

# Worker Attributes
default["test_looper_worker"]["data_bag_key"] = "test-looper/worker.json"
default["test_looper_worker"]["install_dir"] = "/opt/test-looper"
default["test_looper_worker"]["config_file"] = "test-looper.conf.json"
default["test_looper_worker"]["ccache_size_gb"] = "30"


# Server Attributes
default["test_looper_server"]["data_bag_key"] = "test-looper/server.json"
default["test_looper_server"]["install_dir"] = "/opt/test-looper-server"

default["test_looper_server"]["ssl_dir"] = "/etc/apache2/ssl"
default["test_looper_server"]["ssl_cert_prefix"] = "ufora"
default["test_looper_server"]["dnsname"] = "test-looper.ufora.com"
default["test_looper_server"]["port"] = "7531"
default["test_looper_server"]["http_port"] = "8888"

default["test_looper_server"]["ec2_worker_security_group"] = "sg-06382863"
default["test_looper_server"]["ec2_worker_ami"] = "ami-5b0d346b"
default["test_looper_server"]["ec2_worker_role_name"] = "test-looper"
default["test_looper_server"]["ec2_worker_ssh_key_name"] = "test-looper"
default["test_looper_server"]["ec2_worker_root_volume_size_gb"] = "30"

# External cookbooks
default['apt']['compile_time_update'] = true
