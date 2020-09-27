# Redis

Running [Redis in production on kubernetes](https://medium.com/swlh/production-checklist-for-redis-on-kubernetes-60173d5a5325) requires you to make the correct hardware choices as well as choosing an appropriate deployment method.

## Deploy Redis using operator

This deployment method runs Redis in a master-slave cluster with [Redis Sentinel](https://redis.io/topics/sentinel).

```sh
export $OPERATOR_GITHUB_URL=https://raw.githubusercontent.com/spotahome/redis-operator/v1.0.0/example

# Deploy the operator and CRD
kubectl apply -f ${OPERATOR_GITHUB_URL}/operator/all-redis-operator-resources.yaml

# Deploy redis sentinel service - rfs-redisfailover 
kubectl apply -f ${OPERATOR_GITHUB_URL}/redisfailover/basic.yaml

```

Enable [redis auth](https://github.com/spotahome/redis-operator#enabling-redis-auth) by modifying the basic.yaml and including the redis secret for [redis connection](https://github.com/spotahome/redis-operator#connection-to-the-created-redis-failovers)

## Test Redis connection

Redis does not use HTTP for client connections, so an HTTP client like CURL cannot directly communicate with Redis server.

Without an HTTP interface for Redis, you can use `netcat`

```sh
echo ping | nc <redis_host> 26379
nc -v <redis_host> 26379
# e.g.
echo ping | nc rfs-redisfailover 26379
+PONG
```