# Mounting nfs volumes
```yaml
volumes:
  affine_storage:
    driver: local
    driver_opts:
      type: nfs
      o: addr=10.0.0.195,rw,noatime,rsize=8192,wsize=8192,tcp,timeo=14,nfsvers=4
      device: ":/volume1/decoyVolumeMounts/volumes/affine/affine_storage"
  ```