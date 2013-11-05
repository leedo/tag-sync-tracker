perl -Mlocal::lib=local local/bin/start_server --interval 5 --port localhost:5002 --pid-file tracker.pid -- \
  perl -Mlocal::lib=local local/bin/starman --preload-app --workers 5 -Ilib tracker.psgi &
