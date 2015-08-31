```bash
VERSION=`https://raw.githubusercontent.com/driskell/log-courier/stable/version_short.txt`
echo VERSION=${VERSION}
docker build -t mgrast/log-courier:${VERSION} .
```
