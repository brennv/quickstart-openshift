#!/bin/bash
# openshift error check
/bin/oc get nodes > /root/oseoutput
chmod 755 /root/oseoutput
var1=$(tr -s ' ' '\n' </root/oseoutput| grep -c 'Ready')
# Checks if openshift installed correctly or not
if [ $var1 -ne 3 ];then
   echo "Openshift didn't Installed correctly and reinstalling again"
   ssh -C -tt -v -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o ConnectTimeout=10 ose-master.rhosepaas.com /bin/ansible-playbook /root/openshift-ansible/playbooks/byo/config.yml > /tmp/ose_install.log
/bin/sed -i "s/name: deny_all/name: my_htpasswd_provider/g" /etc/origin/master/master-config.yaml
/bin/sed -i "/kind: DenyAllPasswordIdentityProvider/a \     \ file: /etc/origin/master/users.htpasswd" /etc/origin/master/master-config.yaml
/bin/sed -i "s/kind: DenyAllPasswordIdentityProvider/kind: HTPasswdPasswordIdentityProvider/g" /etc/origin/master/master-config.yaml
yum -y install httpd-tools
useradd ose_user; htpasswd -c -b /etc/origin/master/users.htpasswd ose_user redhat
sleep 10
systemctl restart atomic-openshift-master
fi
yum install -y atomic-openshift-utils
yum install -y atomic-openshift* openshift* etcd
var3=0
/bin/oc get nodes > /root/oseoutput
var2=$(tr -s ' ' '\n' </root/oseoutput| grep -c 'Ready')
while [ $var2 -ne 3 ]; do
    sleep 30
	 echo "Checking openshift Installation -- $var3 loop"
	 var3=$((var3+1))
	/bin/oc get nodes > /root/oseoutput
    var2=$(tr -s ' ' '\n' </root/oseoutput| grep -c 'Ready')
done

if [ $var2 -eq 3 ];then
   echo "Openshift Installed Successfully"
else
   echo "Installation Failed"  
fi

oadm registry --config=/etc/origin/master/admin.kubeconfig --service-account=registry --images='registry.access.redhat.com/openshift3/ose-${component}:${version}' --selector='region=infra' 
systemctl restart atomic-openshift-master
sleep 60
oc label node ose-node1.rhosepaas.com region=infra zone=default
oc get scc privileged -o json | jq '.users |= .+ ["system:serviceaccount:default:router","ose_user"]' | oc replace scc -f -
oadm policy add-cluster-role-to-user cluster-reader system:serviceaccount:default:router
oadm router ose-master --replicas=1 --selector='region=infra' --credentials='/etc/origin/master/openshift-router.kubeconfig' --service-account=router
sleep 60
/bin/oc get pods
echo "checking pods"
cmd=`/bin/oc get pods | wc -l`
if [ $cmd -le 2 ] ; then
  echo "COMPLETETION FAILED"
else
 echo "COMPLETED SUCCUSSFULLY !!!"
fi

