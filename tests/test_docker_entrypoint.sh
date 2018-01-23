#!/usr/bin/env bash

run_pipeline() {
    TEMPDIR=${1:-$(mktemp -d)}
    PIPELINES_SCRIPT="${2}"
    PIPELINES_TEST="${3}"
    DOCKER_RUN_ARGS="${4}"
    docker rm --force sk8s-pipelines-tests >/dev/null 2>&1
    docker run --rm --name=sk8s-pipelines-tests \
               -v $TEMPDIR:/pipelines/data \
               -e PIPELINES_SCRIPT="${PIPELINES_SCRIPT}" $DOCKER_RUN_ARGS sk8s-pipelines &&\
    pushd $TEMPDIR >/dev/null &&\
    eval "${PIPELINES_TEST}" &&\
    popd >/dev/null
    RES=$?
    [ "${1}" == "" ] && sudo rm -rf "${TEMPDIR}"
    return $RES
}

run_noise_pipeline() {
    TEMPDIR="${1}"
    DOCKER_RUN_ARGS="${2}"
    run_pipeline "${TEMPDIR}" "dpp run ./noise" "ls -lah noise/datapackage.json &&\
                                                 ls -lah noise/noise.csv" "${DOCKER_RUN_ARGS}"
}

run_amplify_pipeline() {
    TEMPDIR="${1}"
    DOCKER_RUN_ARGS="${2}"
    run_pipeline "${TEMPDIR}" "dpp run ./amplify" "ls -lah amplified-noise/datapackage.json &&\
                                                   ls -lah amplified-noise/noise.csv" "${DOCKER_RUN_ARGS}"
}

run_pipelines() {
    DOCKER_RUN_ARGS="${1}"
    TEMPDIR=`mktemp -d`
    run_noise_pipeline "${TEMPDIR}" "${DOCKER_RUN_ARGS}" && run_amplify_pipeline "${TEMPDIR}" "${DOCKER_RUN_ARGS}"
    RES=$?
    sudo rm -rf "${TEMPDIR}"
    return $RES
}

test_title() {
    echo
    echo "-- $@"
}

test_baseline() {
    test_title "running without PIPELINES_SCRIPT should exit with error"
    docker run sk8s-pipelines && exit 1

    test_title "false PIPELINES_SCRIPT should exit with error"
    docker run -e PIPELINES_SCRIPT=false sk8s-pipelines && exit 1

    test_title "true PIPELINES_SCRIPT should exit successfully"
     ! docker run -e PIPELINES_SCRIPT=true sk8s-pipelines && exit 1

    test_title "noise and amplify pipelines should run successfully and save data in /pipelines/data"
    ! run_pipelines && exit 1
}

start_metrics() {
    stop_metrics
    docker network create sk8s-pipelines-influxdb
    docker run -p 8086:8086 -d --name=influxdb --network=sk8s-pipelines-influxdb --network-alias=influxdb influxdb >/dev/null
    sleep .1
    while ! curl -s http://localhost:8086/ping >/dev/null; do
        sleep .1
    done
}

stop_metrics() {
    docker rm --force influxdb >/dev/null 2>&1
    docker network rm sk8s-pipelines-influxdb >/dev/null 2>&1
}

test_metrics() {
    test_title "metrics should be sent when metrics is enabled"
    start_metrics
    run_pipelines "--network=sk8s-pipelines-influxdb
                   -e METRICS_HOST=http://influxdb:8086
                   -e METRICS_DB=pipelines
                   -e METRICS_TAGS_PREFIX=,environment=staging,pipeline=" &&\
    R=$(curl -sG 'http://localhost:8086/query' --data-urlencode "db=pipelines" \
             --data-urlencode "q=SELECT * FROM \"success\" WHERE \"environment\"='staging'") &&\
    echo "R=${R}" &&\
    [ "$(echo $R | jq -r '.results[0].series[0].name')" == "success" ] &&\
    [ "$(echo $R | jq -r '.results[0].series[0].values[0][3]')" == "1" ] &&\
    [ "$(echo $R | jq -r '.results[0].series[0].values[2]')" == "null" ] &&\
    [ "$(echo $R | jq -r '.results[0].series[1]')" == "null" ] &&\
    [ "$(echo $R | jq -r '.results[1]')" == "null" ]
    RES=$?
    stop_metrics
    [ "${RES}" != "0" ] && exit $RES
}

test_state() {
    test_title "states should be updated"
    export STATE_TEMPDIR=`mktemp -d`
    (
        run_noise_pipeline "" "-e STATE_PATH=/state
                               -e INITIAL_SYNC_STATE_FILENAME=initial_sync_complete
                               -e INITIAL_SYNC_STATE_RETRY_INTERVAL_SECONDS=1
                               -e DONE_STATE_FILENAME=pipelines_complete
                               -e EXIT_STATE_FILENAME=exit
                               -e EXIT_STATE_RETRY_INTERVAL_SECONDS=1"
        RES=$?
        echo "${RES}" > "${STATE_TEMPDIR}/pipelines_res"
    ) &
    sleep 2
    ! [ -e "${STATE_TEMPDIR}/pipelines_res" ] &&\
    docker exec sk8s-pipelines-tests bash -c "touch /state/initial_sync_complete" &&\
    while ! docker exec sk8s-pipelines-tests bash -c "ls /state/pipelines_complete >/dev/null 2>&1"; do sleep 1; done &&\
    sleep 2 &&\
    ! [ -e "${STATE_TEMPDIR}/pipelines_res" ] &&\
    docker exec sk8s-pipelines-tests bash -c "touch /state/exit" &&\
    while ! [ -e "${STATE_TEMPDIR}/pipelines_res" ]; do sleep 1; done &&\
    [ $(cat "${STATE_TEMPDIR}/pipelines_res") == "0" ]
    RES=$?
    sudo rm -rf "${STATE_TEMPDIR}"
    docker rm --force sk8s-pipelines-tests >/dev/null 2>&1
    sleep 2
    [ "${RES}" != "0" ] && exit $RES
}

test_serve() {
    test_title "server should be serving"
    export STATE_TEMPDIR=`mktemp -d`
    (
        run_noise_pipeline "" "-e STATE_PATH=/state
                               -e DONE_STATE_FILENAME=pipelines_complete
                               -e EXIT_STATE_FILENAME=exit
                               -e EXIT_STATE_RETRY_INTERVAL_SECONDS=1
                               -p 5000:5000"
        RES=$?
        echo "${RES}" > "${STATE_TEMPDIR}/pipelines_res"
    ) &
    sleep 2
    ! [ -e "${STATE_TEMPDIR}/pipelines_res" ] &&\
    while ! docker exec sk8s-pipelines-tests bash -c "ls /state/pipelines_complete >/dev/null 2>&1"; do sleep 1; done &&\
    sleep 2 &&\
    curl -I http://localhost:5000/ &&\
    ! [ -e "${STATE_TEMPDIR}/pipelines_res" ] &&\
    docker exec sk8s-pipelines-tests bash -c "touch /state/exit" &&\
    while ! [ -e "${STATE_TEMPDIR}/pipelines_res" ]; do sleep 1; done &&\
    [ $(cat "${STATE_TEMPDIR}/pipelines_res") == "0" ]
    RES=$?
    sudo rm -rf "${STATE_TEMPDIR}"
    docker rm --force sk8s-pipelines-tests >/dev/null 2>&1
    sleep 2
    [ "${RES}" != "0" ] && exit $RES
}

# ensure we have sudo
sudo true

docker build -t sk8s-pipelines .
test_baseline
test_metrics
test_state
test_serve

echo "Great Success!"
exit 0
