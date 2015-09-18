

To ssh into CoreOS:

```bash
eval $(ssh-agent)
ssh-add ~/.ssh/<your_key>
ssh -A core@<instance>
```


Or modify you .bashrc
```bash
if [[ $- == *i* ]]
then
    # do_interactive_stuff
    eval $(ssh-agent)
    ssh-add ~/.ssh/<your_key>
fi

alias coreos="ssh -i ~/.ssh/<your_key> -oBatchMode=yes -oStrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -l core "
```

The alias is helpful when your CoreOS instance ist PXE-booting without a static host key.