# 10. Troubleshooting - Debug và Giải quyết Vấn đề

## Mục tiêu
- Master troubleshooting methodology
- Debug common Kubernetes issues
- Performance analysis và optimization
- Network troubleshooting
- Storage và persistent volume issues

## Troubleshooting Methodology

### 1. Systematic Approach
```
Problem Report
      ↓
Gather Information
      ↓
Reproduce Issue
      ↓
Isolate Root Cause
      ↓
Implement Solution
      ↓
Verify Fix
      ↓
Document Solution
```

### 2. Information Gathering Checklist
- [ ] What changed recently?
- [ ] When did the issue start?
- [ ] Is it affecting all users or specific ones?
- [ ] What error messages are shown?
- [ ] What is the expected vs actual behavior?

## Common Issues và Solutions

### 🔴 Pod Issues

#### Pod Stuck in Pending
```bash
# Check pod status
kubectl describe pod <pod-name>

# Common causes:
# 1. Insufficient resources
kubectl top nodes
kubectl describe nodes

# 2. Node selector/affinity issues
kubectl get nodes --show-labels

# 3. Taints and tolerations
kubectl describe node <node-name> | grep -i taint

# 4. PVC not bound
kubectl get pvc
```

#### Pod Crash Loop
```bash
# Check pod logs
kubectl logs <pod-name> --previous
kubectl logs <pod-name> -c <container-name>

# Check resource limits
kubectl describe pod <pod-name>

# Check liveness/readiness probes
kubectl get pod <pod-name> -o yaml | grep -A 10 livenessProbe
```

#### ImagePullBackOff
```bash
# Check image name and tag
kubectl describe pod <pod-name>

# Check image pull secrets
kubectl get secrets
kubectl describe secret <secret-name>

# Test image pull manually
docker pull <image-name>
```

### 🌐 Network Issues

#### Service Not Accessible
```bash
# Check service endpoints
kubectl get endpoints <service-name>
kubectl describe service <service-name>

# Check pod labels
kubectl get pods --show-labels

# Test service connectivity
kubectl run test-pod --image=busybox --rm -it -- /bin/sh
# nslookup <service-name>
# wget -qO- <service-name>:<port>
```

#### DNS Resolution Issues
```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test DNS resolution
kubectl run test-dns --image=busybox --rm -it -- /bin/sh
# nslookup kubernetes.default
# nslookup <service-name>.<namespace>.svc.cluster.local

# Check CoreDNS configuration
kubectl get configmap coredns -n kube-system -o yaml
```

#### Network Policy Issues
```bash
# Check network policies
kubectl get networkpolicy -A
kubectl describe networkpolicy <policy-name>

# Test connectivity
kubectl exec -it <pod-name> -- nc -zv <target-ip> <port>

# Check CNI logs
kubectl logs -n kube-system -l app=calico-node
```

### 💾 Storage Issues

#### PVC Stuck in Pending
```bash
# Check PVC status
kubectl describe pvc <pvc-name>

# Check storage class
kubectl get storageclass
kubectl describe storageclass <storage-class>

# Check available PVs
kubectl get pv

# Check node capacity
kubectl describe nodes | grep -A 5 "Allocated resources"
```

#### Mount Issues
```bash
# Check pod events
kubectl describe pod <pod-name>

# Check volume mounts
kubectl get pod <pod-name> -o yaml | grep -A 10 volumeMounts

# Check file permissions
kubectl exec -it <pod-name> -- ls -la /mount/path
```

### ⚡ Performance Issues

#### High CPU Usage
```bash
# Check resource usage
kubectl top pods --sort-by=cpu
kubectl top nodes

# Check resource limits
kubectl describe pod <pod-name> | grep -A 5 Limits

# Profile application
kubectl exec -it <pod-name> -- top
kubectl exec -it <pod-name> -- ps aux
```

#### High Memory Usage
```bash
# Check memory usage
kubectl top pods --sort-by=memory

# Check for memory leaks
kubectl logs <pod-name> | grep -i "out of memory\|oom"

# Check memory limits
kubectl describe pod <pod-name> | grep -A 5 Limits
```

#### Slow Application Response
```bash
# Check application logs
kubectl logs <pod-name> --tail=100

# Check network latency
kubectl exec -it <pod-name> -- ping <target-service>

# Check database connections
kubectl exec -it <pod-name> -- netstat -an | grep ESTABLISHED
```

## Debug Tools và Commands

### Essential kubectl Commands
```bash
# Get cluster info
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods --all-namespaces

# Describe resources
kubectl describe node <node-name>
kubectl describe pod <pod-name>
kubectl describe service <service-name>

# Check logs
kubectl logs <pod-name> --previous
kubectl logs <pod-name> -c <container-name> --follow

# Execute commands in pods
kubectl exec -it <pod-name> -- /bin/bash
kubectl exec -it <pod-name> -c <container-name> -- /bin/sh

# Port forwarding for debugging
kubectl port-forward pod/<pod-name> 8080:80
kubectl port-forward service/<service-name> 8080:80

# Copy files
kubectl cp <pod-name>:/path/to/file ./local-file
kubectl cp ./local-file <pod-name>:/path/to/file
```

### Advanced Debugging
```bash
# Debug with ephemeral containers (K8s 1.23+)
kubectl debug -it <pod-name> --image=busybox --target=<container-name>

# Create debug pod
kubectl run debug-pod --image=nicolaka/netshoot --rm -it -- /bin/bash

# Check resource usage
kubectl top pods --containers
kubectl top nodes

# Get events
kubectl get events --sort-by=.metadata.creationTimestamp
kubectl get events --field-selector involvedObject.name=<pod-name>

# Check API server logs
kubectl logs -n kube-system kube-apiserver-<master-node>
```

## Network Troubleshooting

### Connectivity Testing
```bash
# Test pod-to-pod communication
kubectl exec -it <source-pod> -- ping <target-pod-ip>
kubectl exec -it <source-pod> -- nc -zv <target-ip> <port>

# Test service connectivity
kubectl exec -it <pod-name> -- wget -qO- <service-name>:<port>
kubectl exec -it <pod-name> -- curl -v <service-name>:<port>

# DNS testing
kubectl exec -it <pod-name> -- nslookup <service-name>
kubectl exec -it <pod-name> -- dig <service-name>.<namespace>.svc.cluster.local

# Check routing
kubectl exec -it <pod-name> -- ip route
kubectl exec -it <pod-name> -- traceroute <target-ip>
```

### Network Policy Debugging
```bash
# List all network policies
kubectl get networkpolicy --all-namespaces

# Check policy details
kubectl describe networkpolicy <policy-name> -n <namespace>

# Test connectivity with policy
kubectl exec -it <pod-name> -- nc -zv <target-service> <port>

# Check CNI logs
kubectl logs -n kube-system -l k8s-app=calico-node
kubectl logs -n kube-system -l app=weave-net
```

## Performance Analysis

### Resource Monitoring
```bash
# Node resource usage
kubectl top nodes
kubectl describe node <node-name> | grep -A 5 "Allocated resources"

# Pod resource usage
kubectl top pods --all-namespaces --sort-by=cpu
kubectl top pods --all-namespaces --sort-by=memory

# Container resource usage
kubectl top pods --containers

# Check resource limits
kubectl describe pod <pod-name> | grep -A 10 "Limits\|Requests"
```

### Application Performance
```bash
# Check application metrics
kubectl port-forward <pod-name> 8080:8080
curl http://localhost:8080/metrics

# Profile CPU usage
kubectl exec -it <pod-name> -- top
kubectl exec -it <pod-name> -- ps aux --sort=-%cpu

# Profile memory usage
kubectl exec -it <pod-name> -- free -h
kubectl exec -it <pod-name> -- ps aux --sort=-%mem

# Check disk I/O
kubectl exec -it <pod-name> -- iostat -x 1
kubectl exec -it <pod-name> -- df -h
```

## Storage Troubleshooting

### PVC Issues
```bash
# Check PVC status
kubectl get pvc --all-namespaces
kubectl describe pvc <pvc-name>

# Check storage class
kubectl get storageclass
kubectl describe storageclass <storage-class>

# Check PV availability
kubectl get pv
kubectl describe pv <pv-name>

# Check provisioner logs
kubectl logs -n kube-system -l app=csi-driver
```

### Mount Issues
```bash
# Check mount points
kubectl exec -it <pod-name> -- mount | grep <volume-name>
kubectl exec -it <pod-name> -- df -h

# Check file permissions
kubectl exec -it <pod-name> -- ls -la /mount/path

# Check volume configuration
kubectl get pod <pod-name> -o yaml | grep -A 20 volumes
```

## Security Troubleshooting

### RBAC Issues
```bash
# Check permissions
kubectl auth can-i <verb> <resource> --as=<user>
kubectl auth can-i --list --as=<user>

# Check service account
kubectl get serviceaccount <sa-name>
kubectl describe serviceaccount <sa-name>

# Check role bindings
kubectl get rolebinding,clusterrolebinding --all-namespaces
kubectl describe rolebinding <binding-name>
```

### Pod Security Issues
```bash
# Check security context
kubectl get pod <pod-name> -o yaml | grep -A 10 securityContext

# Check pod security policy
kubectl get psp
kubectl describe psp <policy-name>

# Check admission controller logs
kubectl logs -n kube-system kube-apiserver-<master> | grep admission
```

## Cluster-level Troubleshooting

### Control Plane Issues
```bash
# Check control plane pods
kubectl get pods -n kube-system

# Check API server
kubectl logs -n kube-system kube-apiserver-<master>

# Check etcd
kubectl logs -n kube-system etcd-<master>

# Check scheduler
kubectl logs -n kube-system kube-scheduler-<master>

# Check controller manager
kubectl logs -n kube-system kube-controller-manager-<master>
```

### Node Issues
```bash
# Check node status
kubectl get nodes
kubectl describe node <node-name>

# Check kubelet logs
journalctl -u kubelet -f

# Check container runtime
systemctl status docker
systemctl status containerd

# Check node resources
kubectl top node <node-name>
kubectl describe node <node-name> | grep -A 5 "Allocated resources"
```

## Monitoring và Alerting

### Metrics Collection
```bash
# Check metrics server
kubectl get pods -n kube-system -l k8s-app=metrics-server

# Get resource metrics
kubectl top nodes
kubectl top pods --all-namespaces

# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Visit http://localhost:9090/targets
```

### Log Analysis
```bash
# Centralized logging
kubectl logs -n logging -l app=elasticsearch
kubectl logs -n logging -l app=fluentd

# Application logs
kubectl logs <pod-name> --since=1h
kubectl logs <pod-name> --tail=100 -f

# System logs
journalctl -u kubelet --since="1 hour ago"
journalctl -u docker --since="1 hour ago"
```

## Emergency Procedures

### Quick Fixes
```bash
# Restart deployment
kubectl rollout restart deployment <deployment-name>

# Scale deployment
kubectl scale deployment <deployment-name> --replicas=0
kubectl scale deployment <deployment-name> --replicas=3

# Delete stuck pod
kubectl delete pod <pod-name> --force --grace-period=0

# Cordon node
kubectl cordon <node-name>
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Emergency rollback
kubectl rollout undo deployment <deployment-name>
```

### Disaster Recovery
```bash
# Backup etcd
ETCDCTL_API=3 etcdctl snapshot save backup.db

# Restore from backup
velero restore create --from-backup <backup-name>

# Check cluster health
kubectl get componentstatuses
kubectl cluster-info dump
```

## Best Practices

### Troubleshooting Mindset
1. **Stay Calm**: Systematic approach beats panic
2. **Gather Facts**: Don't assume, verify
3. **Start Simple**: Check obvious things first
4. **Document**: Record findings and solutions
5. **Learn**: Understand root cause, not just symptoms

### Prevention
1. **Monitoring**: Comprehensive observability
2. **Testing**: Regular disaster recovery drills
3. **Documentation**: Keep runbooks updated
4. **Training**: Team knowledge sharing
5. **Automation**: Reduce human error

## Quick Reference

### Most Used Commands
```bash
# Status checks
kubectl get pods -o wide
kubectl describe pod <pod-name>
kubectl logs <pod-name> --previous

# Network debugging
kubectl exec -it <pod-name> -- ping <target>
kubectl get svc,endpoints

# Resource checks
kubectl top nodes
kubectl top pods --sort-by=cpu

# Events
kubectl get events --sort-by=.metadata.creationTimestamp
```

### Emergency Contacts
- Platform Team: #platform-team
- SRE Team: #sre-oncall
- Security Team: #security-incidents
- Escalation: manager@company.com

## Next Steps

Congratulations! Bạn đã hoàn thành toàn bộ Kubernetes course. Tiếp theo:
1. **Practice**: Apply knowledge trong real projects
2. **Certifications**: CKA, CKAD, CKS
3. **Advanced Topics**: Service Mesh, GitOps, Cloud Native
4. **Community**: Contribute to open source projects