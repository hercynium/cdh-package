#!/bin/bash
set -ex

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

usage() {
  echo "
usage: $0 <options>
  Required not-so-options:
     --extra-dir=DIR    path to Bigtop distribution files
     --build-dir=DIR    path to Bigtop distribution files
     --server-dir=DIR   path to server package root
     --client-dir=DIR   path to the client package root
     --initd-dir=DIR    path to the server init.d directory

  Optional options:
     --docs-dir=DIR     path to the documentation root
  "
  exit 1
}

OPTS=$(getopt \
  -n $0 \
  -o '' \
  -l 'extra-dir:' \
  -l 'build-dir:' \
  -l 'server-dir:' \
  -l 'client-dir:' \
  -l 'docs-dir:' \
  -l 'initd-dir:' \
  -l 'conf-dir:' \
  -- "$@")

if [ $? != 0 ] ; then
    usage
fi

eval set -- "$OPTS"
while true ; do
    case "$1" in
        --extra-dir)
        EXTRA_DIR=$2 ; shift 2
        ;;
        --build-dir)
        BUILD_DIR=$2 ; shift 2
        ;;
        --server-dir)
        SERVER_PREFIX=$2 ; shift 2
        ;;
        --client-dir)
        CLIENT_PREFIX=$2 ; shift 2
        ;;
        --docs-dir)
        DOC_DIR=$2 ; shift 2
        ;;
        --initd-dir)
        INITD_DIR=$2 ; shift 2
        ;;
        --conf-dir)
        CONF_DIR=$2 ; shift 2
        ;;
        --)
        shift; break
        ;;
        *)
        echo "Unknown option: $1"
        usage
        ;;
    esac
done

for var in BUILD_DIR SERVER_PREFIX CLIENT_PREFIX; do
  if [ -z "$(eval "echo \$$var")" ]; then
    echo Missing param: $var
    usage
  fi
done

if [ ! -d "${BUILD_DIR}" ]; then
  echo "Build directory does not exist: ${BUILD_DIR}"
  exit 1
fi

## Install client image first
CLIENT_LIB_DIR=${CLIENT_PREFIX}/usr/lib/oozie
MAN_DIR=${CLIENT_PREFIX}/usr/share/man/man1
DOC_DIR=${DOC_DIR:-$CLIENT_PREFIX/usr/share/doc/oozie}
BIN_DIR=${CLIENT_PREFIX}/usr/bin

install -d -m 0755 ${CLIENT_LIB_DIR}
install -d -m 0755 ${CLIENT_LIB_DIR}/bin
cp -R ${BUILD_DIR}/bin/oozie ${CLIENT_LIB_DIR}/bin
cp -R ${BUILD_DIR}/lib ${CLIENT_LIB_DIR}
install -d -m 0755 ${DOC_DIR}
cp -R ${BUILD_DIR}/LICENSE.txt ${DOC_DIR}
cp -R ${BUILD_DIR}/NOTICE.txt ${DOC_DIR}
cp -R ${BUILD_DIR}/oozie-examples.tar.gz ${DOC_DIR}
cp -R ${BUILD_DIR}/README.txt ${DOC_DIR}
cp -R ${BUILD_DIR}/release-log.txt ${DOC_DIR}
[ -f ${BUILD_DIR}/PATCH.txt ] && cp ${BUILD_DIR}/PATCH.txt ${DOC_DIR}
cp -R ${BUILD_DIR}/docs/* ${DOC_DIR}
rm -rf ${DOC_DIR}/target
install -d -m 0755 ${MAN_DIR}
gzip -c ${EXTRA_DIR}/oozie.1 > ${MAN_DIR}/oozie.1.gz

# Create the /usr/bin/oozie wrapper
install -d -m 0755 $BIN_DIR
cat > ${BIN_DIR}/oozie <<EOF
#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Autodetect JAVA_HOME if not defined
. /usr/lib/bigtop-utils/bigtop-detect-javahome

exec /usr/lib/oozie/bin/oozie "\$@"
EOF
chmod 755 ${BIN_DIR}/oozie


## Install server image
SERVER_LIB_DIR=${SERVER_PREFIX}/usr/lib/oozie
CONF_DIR=${CONF_DIR:-"${SERVER_PREFIX}/etc/oozie/conf.dist"}
DATA_DIR=${SERVER_PREFIX}/var/lib/oozie

install -d -m 0755 ${SERVER_LIB_DIR}
install -d -m 0755 ${SERVER_LIB_DIR}/bin
install -d -m 0755 ${DATA_DIR}
install -d -m 0755 ${DATA_DIR}/work
for file in ooziedb.sh oozied.sh oozie-sys.sh ; do
  cp ${BUILD_DIR}/bin/$file ${SERVER_LIB_DIR}/bin
done

install -d -m 0755 ${CONF_DIR}
cp -r ${BUILD_DIR}/conf/* ${CONF_DIR}
sed -i -e '/oozie.service.HadoopAccessorService.hadoop.configurations/,/<\/property>/s#<value>\*=hadoop-conf</value>#<value>*=/etc/hadoop/conf</value>#g' \
          ${CONF_DIR}/oozie-site.xml
cp ${EXTRA_DIR}/oozie-env.sh ${CONF_DIR}
install -d -m 0755 ${CONF_DIR}/action-conf
cp ${EXTRA_DIR}/hive.xml ${CONF_DIR}/action-conf
if [ "${INITD_DIR}" != "" ]; then
  install -d -m 0755 ${INITD_DIR}
  cp -R ${EXTRA_DIR}/oozie.init ${INITD_DIR}/oozie
  chmod 755 ${INITD_DIR}/oozie
fi
mv ${BUILD_DIR}/oozie-sharelib-*-yarn.tar.gz ${SERVER_LIB_DIR}/oozie-sharelib-yarn.tar.gz
mv ${BUILD_DIR}/oozie-sharelib-*.tar.gz ${SERVER_LIB_DIR}/oozie-sharelib-mr1.tar.gz
ln -s oozie-sharelib-mr1.tar.gz ${SERVER_LIB_DIR}/oozie-sharelib.tar.gz
cp -R ${BUILD_DIR}/oozie-server/webapps ${SERVER_LIB_DIR}/webapps
ln -s -f /etc/oozie/conf/oozie-env.sh ${SERVER_LIB_DIR}/bin

# Unpack oozie.war some place reasonable
OOZIE_WEBAPP=${SERVER_LIB_DIR}/webapps/oozie
mkdir ${OOZIE_WEBAPP}
unzip -d ${OOZIE_WEBAPP} ${BUILD_DIR}/oozie.war
mv -f ${OOZIE_WEBAPP}/WEB-INF/lib ${SERVER_LIB_DIR}/libserver
touch ${SERVER_LIB_DIR}/webapps/oozie.war

# Create all the jars needed for tools execution
install -d -m 0755 ${SERVER_LIB_DIR}/libtools
for i in `cd ${BUILD_DIR}/libtools ; ls *` ; do
  if [ -e ${SERVER_LIB_DIR}/libserver/$i ] ; then
    ln -s ../libserver/$i ${SERVER_LIB_DIR}/libtools/$i
  else
    cp ${BUILD_DIR}/libtools/$i ${SERVER_LIB_DIR}/libtools/$i
  fi
done

# Create an exploded-war oozie deployment in /usr/lib/oozie/oozie-server for MR2
install -d -m 0755 ${SERVER_LIB_DIR}/oozie-server
ln -s /var/lib/oozie/work ${SERVER_LIB_DIR}/oozie-server
cp -R ${BUILD_DIR}/oozie-server/conf ${SERVER_LIB_DIR}/oozie-server/conf
cp ${EXTRA_DIR}/context.xml ${SERVER_LIB_DIR}/oozie-server/conf/
cp ${EXTRA_DIR}/catalina.properties ${SERVER_LIB_DIR}/oozie-server/conf/
ln -s ../webapps ${SERVER_LIB_DIR}/oozie-server/webapps

# Provide a convenience symlink to be more consistent with tarball deployment
ln -s ${DATA_DIR#${SERVER_PREFIX}} ${SERVER_LIB_DIR}/libext

# Create an exploded-war oozie deployment in /usr/lib/oozie/oozie-server-0.20 for MR1
cp -r ${SERVER_LIB_DIR}/oozie-server ${SERVER_LIB_DIR}/oozie-server-0.20
cp -f ${EXTRA_DIR}/catalina.properties.mr1 ${SERVER_LIB_DIR}/oozie-server-0.20/conf/catalina.properties

# Create an exploded-war oozie deployment in /usr/lib/oozie/oozie-server-ssl for SSL
cp -r ${SERVER_LIB_DIR}/oozie-server ${SERVER_LIB_DIR}/oozie-server-ssl
cp -r ${SERVER_LIB_DIR}/webapps ${SERVER_LIB_DIR}/webapps-ssl
rm -r ${SERVER_LIB_DIR}/oozie-server-ssl/webapps
ln -s ../webapps-ssl ${SERVER_LIB_DIR}/oozie-server-ssl/webapps
cp ${BUILD_DIR}/oozie-server/conf/ssl/ssl-server.xml ${SERVER_LIB_DIR}/oozie-server-ssl/conf/server.xml
cp ${BUILD_DIR}/oozie-server/conf/ssl/ssl-web.xml ${SERVER_LIB_DIR}/webapps-ssl/oozie/WEB-INF/web.xml

# Create an exploded-war oozie deployment in /usr/lib/oozie/oozie-server-0.20-ssl for MR1 for SSL
cp -r ${SERVER_LIB_DIR}/oozie-server-0.20 ${SERVER_LIB_DIR}/oozie-server-0.20-ssl
rm -r ${SERVER_LIB_DIR}/oozie-server-0.20-ssl/webapps
ln -s ../webapps-ssl ${SERVER_LIB_DIR}/oozie-server-0.20-ssl/webapps
cp ${SERVER_LIB_DIR}/oozie-server-0.20/conf/ssl/ssl-server.xml ${SERVER_LIB_DIR}/oozie-server-0.20-ssl/conf/server.xml

# Cloudera specific
install -d -m 0755 ${SERVER_LIB_DIR}/cloudera
cp ${BUILD_DIR}/cloudera/cdh_version.properties ${SERVER_LIB_DIR}/cloudera/

# Replace every Avro jar with a symlink to the versionless symlinks in our Avro distribution
# This regex matches upstream versions, plus CDH versions, betas and snapshots if they are present
versions='s#-[0-9].[0-9].[0-9]\(-cdh[0-9\-\.]*\)\?\(-beta-[0-9]\+\)\?\(-SNAPSHOT\)\?##'
for dir in ${SERVER_LIB_DIR}/libtools ${SERVER_LIB_DIR}/libserver ; do
    for old_jar in `ls $dir/avro-*.jar` ; do
        # Our Avro distribution does not include Cassandra or test JARs and we should remove them from the rest of CDH
        if [[ "$old_jar" =~ "-cassandra" || "$old_jar" =~ "-tests" ]] ; then continue; fi
        new_jar=`echo \`basename $old_jar\` | sed -e $versions`
        rm $old_jar && ln -fs /usr/lib/avro/$new_jar $dir/
    done
done

