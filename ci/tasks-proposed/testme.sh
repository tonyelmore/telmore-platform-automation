set -eux

echo "String from param is: ${SOME_STRING}"
if [ $FAIL_FLAG == "true" ]; then
    echo "Making the task fail"
    exit 1
fi

echo "Task succeeded"
