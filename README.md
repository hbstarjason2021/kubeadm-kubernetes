# kubeadm-kubernetes


## For MAC Users

Latest version of Virtualbox for Mac/Linux can cause issues because you have to create/edit the /etc/vbox/networks.conf file and add:
<pre>* 0.0.0.0/0 ::/0</pre>

or run below commands
```sh
sudo mkdir -p /etc/vbox/
echo * 0.0.0.0/0 ::/0 | sudo tee -a /etc/vbox/networks.conf
```

So that the host only networks can be in any range, not just 192.168.56.0/21 as described here:
https://discuss.hashicorp.com/t/vagrant-2-2-18-osx-11-6-cannot-create-private-network/30984/23
