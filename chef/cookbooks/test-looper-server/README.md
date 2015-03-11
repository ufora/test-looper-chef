# test-looper-server

Deploys and configures test-looper-server and all its dependencies

Setting up your workstation:
1. Install ChefDK
2. Create a ~/chef-repo directory. This will act as your local "chef server".
3. Create a ~/chef-repo/.chef directory
4. Create a symlink ~/chef-repo/.chef/kitchen.rb pointing at /chef/.chef/kitchen.rb in this repo.
5. Run `chef gem install knife-zero`
6. Define the EDITOR environment variable and point it at your editor of choice.
7. Create an encryption key for your chef environment:
   openssl rand -base64 512 > ~/chef-repo/encrypted_data_bag_secret
8. Create an encrypted data bag with all deployment secrets:
   knife data bag create -z --secret-file ~/chef-repo/encrypted_data_bag_secret test-looper server

   This will open a text editor with a skeleton json file. You'll need to add the following keys:
   "github_api_token": a GitHub authentication token associated with the account identified by the
                       'github_login' attribute (ufora-bot by default)
   "test_looper_github_webhook_secret": the secret associated with the GitHub web hook defined for 
                                        a test-looper deployment
   "test_looper_github_app_client_secret": the Client Secret of the GitHub OAuth application defined for
                                           a test-looper deployment
   "git_deploy_key": a github deployment key for the main repo with all new-lines replaced with "\n"
   "ssl_public_cert": the public .crt file to be deployed as an SSL certificate
   "ssl_private_key": the private .key file to be deployed as an SSL certificate
   "ssl_chain": the .ca file to be deployed as an SSL certificate


To deploy:
1. From ~/chef-repo run:
   berks vendor cookbooks -b <test-looper-repo>/chef/cookbooks/test-looper-server/Berksfile

  This will create a ~/chef-repo/cookbooks directory with the test-looper-server cookbook and all its
  dependencies.
2. Run:
   knife zero bootstrap <hostname> -x ubuntu -i <ssh_key> --sudo -r test-looper-server --secret-file ./encrypted_data_bag_secret
