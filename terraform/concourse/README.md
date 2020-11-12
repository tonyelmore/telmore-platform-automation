I spent some time setting this up quite some time ago - but haven't touched in months.
Today (11/11/2020) I deleted all the resource groups in Azure to try this process again.
The results have been mostly postive ...
1) First was the terraform for concourse on azure - that ran with no problems
2) Ran the 0-set-env.sh to set up the usernames and passwords
3) Ran the 1-run-all.sh and it deployed concourse 
4) The 2-xxx script isn't very good yet - the part about downloading the fly cli ... so I just did the "fly login"

Then I ran the terraform for sbx on azure - so far no problems have been found with that

Now I'm double checking the "tf2credhub" scripts to see what state those are in
* The azure_tf2credhub_opsman.sh worked (not sure all the needed values are there)
* The azure_tf2vars_osman.sh worked (not sure all the needed values are there)
* The azure_tf2vars_director.sh isn't even close to being right