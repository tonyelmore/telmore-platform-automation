The test-pipeline-director and test-pipeline-products are only here to show how to effectively use git and not kick off the other pipelines.

The bottom line is that if you do a `git pull --rebase` then the history is maintained and you will not be kicking off pipelines inadvertenly.  The other option is to set the default behavior of `git pull` to be a rebase instead of a merge.  To do that, you issue `git config --global pull.rebase true`.  


You can see the list of all config with `git config --list`.  There may be duplicate entries in this list, but the last one in the list will be what is in effect.


You can also set the default behavior in VSCode to do a rebase instead of a merge when doing a pull.