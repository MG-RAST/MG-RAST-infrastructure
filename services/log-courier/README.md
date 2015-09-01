```bash
VERSION=`curl https://raw.githubusercontent.com/driskell/log-courier/stable/version_short.txt`
echo VERSION=${VERSION}
docker build -t mgrast/log-courier:${VERSION} . 
```
...and to move image into shock:
```bash
~/skycore push mgrast/log-courier:${VERSION}
```
