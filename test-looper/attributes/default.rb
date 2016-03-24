# Environment Attributes
# 
# These MUST be set as custom JSON in OpsWorks
default["test_looper"]["encrypted_data_bag_key"] = ""
default["test_looper_server"]["dnsname"] = ""
default["test_looper_server"]["vpc_subnets"] = {} # a map from AZ to subnet-id
default["test_looper_server"]["worker_ami"] = ""
default["test_looper_server"]["worker_security_group"] = ""
default["test_looper"]["test_results_bucket"] = ""
default["test_looper"]["builds_bucket"] = ""


# Common Attributes
default["test_looper"]["service_account"] = "test-looper"
default["test_looper"]["home_dir"] = "/home/#{default["test_looper"]["service_account"]}"
default["test_looper"]["github_deploy_key_target"] = "id_deploy_target"
default["test_looper"]["github_deploy_key_looper"] = "id_deploy_looper"
default["test_looper"]["git_ssh_wrapper_target_repo"] = "wrap-ssh4git-target.sh"
default["test_looper"]["git_ssh_wrapper_looper_repo"] = "wrap-ssh4git-test-looper.sh"
default["test_looper"]["target_repo"] = "git@github.com:ufora/ufora.git"
default["test_looper"]["looper_repo"] = "git@github.com:ufora/main.git"
default["test_looper"]["git_branch"] = "test-looper-standalone"

default["test_looper"]["data_bag_bucket"] = "ufora-opsworks-us-west-2"

default["test_looper"]["environment"] = "prod"


# Worker Attributes
default["test_looper_worker"]["data_bag_key"] = "test-looper/worker.json"
default["test_looper_worker"]["install_dir"] = "/opt/test-looper"
default["test_looper_worker"]["config_file"] = "test-looper.conf.json"
default["test_looper_worker"]["ccache_size_gb"] = "30"
default["test_looper_worker"]["core_dump_dir"] = "/var/core"


# Server Attributes
default["test_looper_server"]["data_bag_key"] = "test-looper/server.json"
default["test_looper_server"]["install_dir"] = "/opt/test-looper-server"

default["test_looper_server"]["ssl_dir"] = "/etc/apache2/ssl"
default["test_looper_server"]["ssl_cert_prefix"] = "test-looper"
default["test_looper_server"]["port"] = "7531"
default["test_looper_server"]["http_port"] = "8888"

default["test_looper_server"]["ec2_worker_role_name"] = "test-looper"
default["test_looper_server"]["ec2_worker_ssh_key_name"] = "test-looper"
default["test_looper_server"]["ec2_worker_root_volume_size_gb"] = "8"

default["test_looper_server"]["baseline_branch"] = "origin/master"
default["test_looper_server"]["baseline_depth"] = "20"

# Docker configuration
default["test_looper"]["docker"]["graph_dir"] = "/mnt/docker/graph"
default["test_looper"]["docker"]["tmp_dir"] = "/mnt/docker/tmp"

# External cookbooks
default["apt"]["compile_time_update"] = true
default["no_aws"] = false
default["ntp"]["servers"] = ["0.us.pool.ntp.org",
                             "1.us.pool.ntp.org",
                             "2.us.pool.ntp.org",
                             "3.us.pool.ntp.org"]
