# Bootstrap

Bootstrap Linux machines with NVIDIA CUDA driver, docker and nvidia-docker2.

Currently supports Ubuntu 16.04 and 18.04.

Adds the current user to the `docker` group, so `sudo docker` is not required (must log out and back in to take effect).
Sets default runtime for nvidia-docker2 to `nvidia`, so `docker run --runtime=nvidia` is not required each time.

### Running

```
curl https://raw.githubusercontent.com/mikepcw/bootstrap/master/bootstrap.sh | bash -
```

or clone git repo and run:

```
git clone https://github.com/mikepcw/bootstrap
cd bootstrap/
bash ./bootstrap.sh
```
