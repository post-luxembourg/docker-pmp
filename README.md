# ManageEngine Password Manager Pro

![GitHub Actions CI](https://github.com/post-luxembourg/docker-pmp/workflows/GitHub%20Actions%20CI/badge.svg)

## Setup

1. Copy and edit the db config:

```
cp postgres.env.sample postgres.env
vim postgres.env
```

2. Run

```
docker-compose up
```

## Build

### With docker buildx (recommended)

```
./buildx.sh
```

### Without docker buildx (NOT recommended)

```
./build.sh
```

## Similar projects

- https://github.com/babim/docker-me-pmp
- https://github.com/babim/docker-tag-options/tree/master/z%20ManageEngine
