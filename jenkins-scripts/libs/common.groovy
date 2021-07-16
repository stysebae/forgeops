/*
 * Copyright 2019-2021 ForgeRock AS. All Rights Reserved
 *
 * Use of this code requires a commercial software license with ForgeRock AS.
 * or with one of its affiliates. All use shall be exclusively subject
 * to such license between the licensee and ForgeRock AS.
 */

import com.forgerock.pipeline.forgeops.DockerImage
import com.forgerock.pipeline.GlobalConfig

/*
 * Common configuration used by several stages of the ForgeOps pipeline.
 */

/**
 * Globally scoped git commit information
 */
SHORT_GIT_COMMIT = sh(script: 'git rev-parse --short=15 HEAD', returnStdout: true).trim()
GIT_COMMIT = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
GIT_COMMITTER = sh(returnStdout: true, script: 'git show -s --pretty=%cn').trim()
GIT_MESSAGE = sh(returnStdout: true, script: 'git show -s --pretty=%s').trim()
GIT_COMMITTER_DATE = sh(returnStdout: true, script: 'git show -s --pretty=%cd --date=iso8601').trim()
GIT_BRANCH = env.JOB_NAME.replaceFirst(".*/([^/?]+).*", "\$1").replaceAll("%2F", "/")

/** Default platform-images tag corresponding to this branch (or the PR target branch, if this is a PR build) */
DEFAULT_PLATFORM_IMAGES_TAG = "${isPR() ? env.CHANGE_TARGET : env.BRANCH_NAME}-ready-for-dev-pipelines"

/** Revision of platform-images repo used for k8s and platform integration/perf tests. */
platformImagesRevision = bitbucketUtils.getLatestCommitHash(
        GlobalConfig.stashNotifierCredentialsId,
        'cloud',
        'platform-images',
        env.STASH_PLATFORM_IMAGES_BRANCH ?: DEFAULT_PLATFORM_IMAGES_TAG)

/** Revision of Lodestar framework used for K8s and platform integration/perf tests. */
lodestarFileContent = bitbucketUtils.readFileContent(
        'cloud',
        'platform-images',
        platformImagesRevision,
        'lodestar.json').trim()
lodestarRevision = readJSON(text: lodestarFileContent)['gitCommit']

/** Docker image metadata for individual ForgeRock products. */
dockerImages = [
        'am'        : DockerImagePromotion.load('docker/am/Dockerfile', 'gcr.io/forgerock-io/am-base', steps),
        'amster'    : DockerImagePromotion.load('docker/amster/Dockerfile', 'gcr.io/forgerock-io/amster', steps),
        'ds-cts'    : DockerImagePromotion.load('docker/ds/cts/Dockerfile', 'gcr.io/forgerock-io/ds', steps),
        'ds-util'   : DockerImagePromotion.load('docker/ds/dsutil/Dockerfile', 'gcr.io/forgerock-io/ds', steps),
        'ds-idrepo' : DockerImagePromotion.load('docker/ds/idrepo/Dockerfile', 'gcr.io/forgerock-io/ds', steps),
        'ds-proxy'  : DockerImagePromotion.load('docker/ds/proxy/Dockerfile', 'gcr.io/forgerock-io/ds', steps),
        'idm'       : DockerImagePromotion.load('docker/idm/Dockerfile', 'gcr.io/forgerock-io/idm', steps),
        'ig'        : DockerImagePromotion.load('docker/ig/Dockerfile', 'gcr.io/forgerock-io/ig', steps),
]

productToRepo = [
        'am' : 'openam',
        'amster' : 'openam',
        'ds-cts' : 'opendj',
        'ds-util' : 'opendj',
        'ds-idrepo' : 'opendj',
        'ds-proxy' : 'opendj',
        'idm' : 'openidm',
        'ig' : 'openig',
]

DockerImagePromotion getDockerImage(String productName) {
    if (!dockerImages.containsKey(productName)) {
        error "No Dockerfile for image '${productName}'"
    }
    return dockerImages[productName]
}

String getCurrentTag(String productName) {
    return getDockerImage(productName).tag
}

/** Does the branch support PaaS releases */
// TODO Improve the code below to take into account new sustaining branches
// We should only promote version >= 7.1.0
// To be discussed with Bruno and Robin
boolean branchSupportsIDCloudReleases() {
    return 'master' in [env.CHANGE_TARGET, env.BRANCH_NAME] \
            || 'feature/config' in [env.CHANGE_TARGET, env.BRANCH_NAME] \
            || 'release/7.1.0' in [env.CHANGE_TARGET, env.BRANCH_NAME] \
            || (!isPR() && ("${env.BRANCH_NAME}".startsWith('idcloud-') || "${env.BRANCH_NAME}" == 'sustaining/7.1.x')) \
            || (isPR() && ("${env.CHANGE_TARGET}".startsWith('idcloud-') || "${env.CHANGE_TARGET}" == 'sustaining/7.1.x'))
}

def getCurrentProductCommitHashes() {
    return [
            'forgeops' : commonModule.GIT_COMMIT,
            'opendj' : getDockerImage('ds-idrepo').productCommit,
            'openig' : getDockerImage('ig').productCommit,
            'openidm' : getDockerImage('idm').productCommit,
            'openam' : getDockerImage('am').productCommit,
            'lodestar' : getLodestarCommit()
    ]
}

class DockerImagePromotion implements Serializable {
    DockerImage dockerImage
    String rootLevelBaseImageName

    private DockerImagePromotion(DockerImage dockerImage, String rootLevelBaseImageName) {
        this.dockerImage = dockerImage
        this.rootLevelBaseImageName = rootLevelBaseImageName
    }

    static DockerImagePromotion load(String dockerfilePath, String rootLevelBaseImageName, def steps) {
        return new DockerImagePromotion(DockerImage.load(dockerfilePath, steps), rootLevelBaseImageName)
    }

    String getDockerfilePath() { return dockerImage.getDockerfilePath() }
    String getBaseImageName() { return dockerImage.getBaseImageName() }
    String getTag() { return dockerImage.getTag() }
    String getProductCommit() { return dockerImage.getProductCommit() }

    // Overridden methods have to be annotated with @NonCPS to work properly.
    // See https://www.jenkins.io/doc/book/pipeline/cps-method-mismatches/#overrides-of-non-cps-transformed-methods
    @NonCPS
    String toString() {
        return "${dockerImage.toString()}, rootLevelBaseImageName: ${rootLevelBaseImageName}".toString()
    }
}

return this
