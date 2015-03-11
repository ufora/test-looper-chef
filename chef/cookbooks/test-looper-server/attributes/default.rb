default["test_looper_server"]["service_account"] = "ubuntu"
default["test_looper_server"]["install_dir"] = "/opt/test-looper-server"
default["test_looper_server"]["ssl_dir"] = "/etc/apache2/ssl"

default["test_looper_server"]["ssl_cert_prefix"] = "ufora"
default["test_looper_server"]["dnsname"] = "test-looper.ufora.com"
default["test_looper_server"]["http_port"] = "8888"

default["test_looper_server"]["git_ssh_wrapper"] = "wrap-ssh4git.sh"

default["test_looper_server"]["git_repo"] = "git@github.com:ufora/main.git"
default["test_looper_server"]["git_branch"] = "test-looper"
default["test_looper_server"]["github_deploy_key"] = "id_deploy"
default["test_looper_server"]["github_login"] = "ufora-bot"
default["test_looper_server"]["github_oauth_app_id"] = "eb57b8cf7f9122dad732"
