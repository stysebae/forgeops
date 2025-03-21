# Source this file to set the environment variables for the Docker container.

# As of JDK17 the G1 garbage collector is within a few percentage points of parallel GC in terms of throughput for
# small heaps, while providing better determinism and scaling for very large heaps. It also exhibits much less
# off-heap memory overhead compared with JDK11 (less than 10% compared with 20% previously), so it is safer to use it
# in constrained memory environments such as containers.

# The /dev/urandom device is up to 4 times faster for crypto operations in some VM environments
# where the Linux kernel runs low on entropy. This settting does not negatively impact random number security
# and is recommended as the default.

DEFAULT_OPENDJ_JAVA_ARGS="
-XX:+UseG1GC
-XX:+ExitOnOutOfMemoryError
-Djava.security.egd=file:/dev/urandom
-Xlog:gc:${DS_JAVA_GC_LOGFILE:-/opt/opendj/data/gc.log}:time,uptime:filecount=5,filesize=50M
-XX:MaxGCPauseMillis=${DS_JAVA_GC_PAUSE_TARGET:-200}
-XX:MaxRAMPercentage=${DS_JAVA_MAX_RAM_PERCENTAGE:-75}
-XX:MaxTenuringThreshold=${DS_JAVA_MAX_TENURING_THRESHOLD:-1}
${DS_JAVA_ADDITIONAL_ARGS:-}
"

export OPENDJ_JAVA_ARGS=${OPENDJ_JAVA_ARGS:-${DEFAULT_OPENDJ_JAVA_ARGS}}

# Set to true to enable the usage of Java virtual threads
export DS_USE_VIRTUAL_THREADS=${DS_USE_VIRTUAL_THREADS:-false}
OPENDJ_JAVA_ARGS="${OPENDJ_JAVA_ARGS} -Dorg.forgerock.opendj.useVirtualThreads=${DS_USE_VIRTUAL_THREADS}"


# Assume the directory admin and monitor passwords are available at the paths below. 
export DS_SET_UID_ADMIN_AND_MONITOR_PASSWORDS=${DS_SET_UID_ADMIN_AND_MONITOR_PASSWORDS:-"true"}
export DS_UID_MONITOR_PASSWORD_FILE=${DS_UID_MONITOR_PASSWORD_FILE:-"/var/run/secrets/opendj-passwords/monitor.pw"}
export DS_UID_ADMIN_PASSWORD_FILE=${DS_UID_ADMIN_PASSWORD_FILE:-"/var/run/secrets/opendj-passwords/dirmanager.pw"}


# Group Id is important in multi-cluster (multi-region) deployments to localize replication.
# For single cluster deployment, using default is fine.
export DS_GROUP_ID=${DS_GROUP_ID:-default}
# Concat the hostname and group id to make a unique server id. For example
# if ds-idrep-0 is deployed both in groupid=us-west and group-id=us-east, this
# serves to differentiate the two servers.
HID="$(hostname)-$DS_GROUP_ID"
export DS_SERVER_ID=${DS_SERVER_ID:-${HID}}
# By default we advertise to listen on the default hostname
export DS_ADVERTISED_LISTEN_ADDRESS=${DS_ADVERTISED_LISTEN_ADDRESS:-$(hostname -f)}



# If the advertised listen address looks like a Kubernetes pod host name of the form
# <statefulset-name>-<ordinal>.<domain-name> then derived the default bootstrap servers names as
# <statefulset-name>-0.<domain-name>,<statefulset-name>-1.<domain-name>.
#
# Sample hostnames from Kubernetes include:
#
#     ds-1.userstore.svc.cluster.local
#     ds-userstore-1.userstore.svc.cluster.local
#     userstore-1.userstore.jnkns-pndj-bld-pr-4958-1.svc.cluster.local
#     ds-userstore-1.userstore.jnkns-pndj-bld-pr-4958-1.svc.cluster.local
#
# PingDS currently supports various multi-cluster solutions. To deploy in a multi-cluster scenario
# explicitly set the DS_BOOTSTRAP_REPLICATION_SERVERS per your topology. Examples below:
# **Cloud DNS for GKE**
# FQDN:              ds-cts-1.ds-cts.<namespace>.svc.eu
# Results in:
# Server ID:         ds-cts-1_eu
# Group ID:          eu
# Bootstrap servers: ds-cts-0.ds-cts.<namespace>.svc.eu,ds-cts-0.ds-cts.<namespace>.svc.us
#
# **KubeDNS**
# FQDN:              ds-cts-1.ds-cts-eu.<namespace>.svc.cluster.local
# Results in:
# Server ID:         ds-cts-1_eu
# Group ID:          eu
# Bootstrap servers: ds-cts-0.ds-cts-eu.<namespace>.svc.cluster.local,ds-cts-0.ds-cts-us.<namespace>.svc.cluster.local
#
# **GKE multi-cluster Services(MCS) **
# FQDN:              ds-cts-1.ds-cts-eu.eu.<namespace>.svc.cluster.local
# Results in:
# Server ID:         ds-cts-1_eu
# Group ID:          eu
# Bootstrap servers: ds-cts-0.ds-cts-eu.eu.<namespace>.svc.cluster.local,ds-cts-0.ds-cts-us.us.<namespace>.svc.cluster.local
#

# If you do not set the Bootstrap servers, the default is calculated below. This works for a single
# cluster deployment. 
if [[ "${DS_ADVERTISED_LISTEN_ADDRESS}" =~ [^.]+-[0-9]+\..+ ]]; then
    # Domain is everything after the first dot
    podDomain=${DS_ADVERTISED_LISTEN_ADDRESS#*.}
    # Name is everything up to the first dot
    podName=${DS_ADVERTISED_LISTEN_ADDRESS%%.*}
    podPrefix=${podName%-*}

    ds0=${podPrefix}-0.${podDomain}:8989       
    ds1=${podPrefix}-1.${podDomain}:8989
    # Set the default bootstrap servers unless the user explicitly provides it
    export DS_BOOTSTRAP_REPLICATION_SERVERS=${DS_BOOTSTRAP_REPLICATION_SERVERS:-${ds0},${ds1}}
else
    export DS_BOOTSTRAP_REPLICATION_SERVERS=${DS_BOOTSTRAP_REPLICATION_SERVERS:-${DS_ADVERTISED_LISTEN_ADDRESS}:8989}
fi


# These are the default locations of cert-manager generated PEM files are mounted.
# These files must be copied to appropriate location and format expected by the PingDS PEM manager
# TO change these location you must also change the ds-setup.sh script.
export SSL_CERT_DIR="/var/run/secrets/ds-ssl-keypair"
export MASTER_CERT_DIR="/var/run/secrets/ds-master-keypair"
export TRUSTSTORE_DIR="/var/run/secrets/truststore"

echo
echo "Server configured with:"
echo "    Group ID                        : $DS_GROUP_ID"
echo "    Server ID                       : $DS_SERVER_ID"
echo "    Advertised listen address       : $DS_ADVERTISED_LISTEN_ADDRESS"
echo "    Bootstrap replication server(s) : $DS_BOOTSTRAP_REPLICATION_SERVERS"
echo
