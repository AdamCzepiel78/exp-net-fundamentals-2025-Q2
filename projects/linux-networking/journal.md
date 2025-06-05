## Linux Networking 

[Back to Week 1 Overview](../../journal/week1/README.md)<br/>

### DNS Resolver 
change the DNS resolver

```bash 
# changed the /etc/systemd/resolved.conf
...
DNS=8.8.8.8
...

ubuntu@ip-10-200-150-8:~$ systemctl restart systemd-resolved.service

ubuntu@ip-10-200-150-8:~$ resolvectl status 
Global
         Protocols: -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported
  resolv.conf mode: stub
Current DNS Server: 8.8.8.8
       DNS Servers: 8.8.8.8

Link 2 (enX0)
    Current Scopes: DNS
         Protocols: +DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported
Current DNS Server: 10.200.150.2
       DNS Servers: 10.200.150.2
        DNS Domain: eu-central-1.compute.internal

Link 3 (enX1)
    Current Scopes: DNS
         Protocols: +DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported
Current DNS Server: 10.200.150.2
       DNS Servers: 10.200.150.2
        DNS Domain: eu-central-1.compute.internal

```
![](./ubuntu-aws.png)


### WGet vs Curl 

**wget** is mostly for downloading files . It's downloader.<br>
**curl** is a tool that can send and receive data using different protocols also download. It's designed for API calls, debugging and much more.

#### curl examples with json.placeholder api
```bash
## simple query 
curl https://jsonplaceholder.typicode.com/posts | jq

## post request 
curl -X POST https://jsonplaceholder.typicode.com/posts \
  -H "Content-Type: application/json" \
  -d '{
    "title": "My New Post",
    "body": "This is the content of my post",
    "userId": 1
  }'

## response headers
curl -I https://jsonplaceholder.typicode.com/posts/1
```

## wget examples 
```bash 
# download json to file 
wget -O all_posts.json https://jsonplaceholder.typicode.com/posts

# download to directory to json file 
wget -P /tmp/ -O all_posts.json https://jsonplaceholder.typicode.com/posts/1
```