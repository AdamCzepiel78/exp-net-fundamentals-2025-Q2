## HA Proxy Loadbalancing

[Back to Week 2 Overview](../../journal/week2/README.md)<br/>
[Back to Journal](../../journal/README.md)<br/>
[Back to Main](../../README.md)

We have now set up a forward proxy, a reverse proxy, and a VPN. In the following example, we want to set up an HAProxy load balancer that performs load balancing between two web servers.

### Goal 

We have now set up a forward proxy, a reverse proxy, and a VPN. In the following example, we want to set up an HAProxy load balancer that performs load balancing between two web servers.

### Considerations 

In Tims HAProxy Clip he setup haproxy with containerlab. I dont want to install containerlab so i will setup haproxy with docker compose and nginx webservers. 

### Investigation

* haproxy container image exists 
* nginx container image exists 
* docker and docker compose is installed
* docker compose file setup with bind mounts for config
* create nginx and haproxy conf files 
* create index.html pages 
* start docker compose

#### Docker Compose 
```yaml
services:
  haproxy:
    image: haproxy:2.8
    container_name: haproxy-lb
    ports:
      - "80:80"
    volumes:
      - ./haproxy/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
    depends_on:
      - webserver1
      - webserver2
    networks:
      - web-network

  # Webserver 1
  webserver1:
    image: nginx:alpine
    container_name: webserver1
    volumes:
      - ./webserver1/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./webserver1/index.html:/usr/share/nginx/html/index.html:ro
    networks:
      - web-network

  # Webserver 2
  webserver2:
    image: nginx:alpine
    container_name: webserver2
    volumes:
      - ./webserver2/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./webserver2/index.html:/usr/share/nginx/html/index.html:ro
    networks:
      - web-network

networks:
  web-network:
    driver: bridge
```

### Outcomes 

The setup works well, haproxy has no issue. 

![](./web1.png)
![](./web2.png)