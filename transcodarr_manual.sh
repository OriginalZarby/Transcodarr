#!/bin/bash
IFS=$'\n';
pathToFiles="";
sonarrRootFolder="";
pathOfRootFolder="";
serverIp="";
serverPort="";
pathOfFailedDatabase="";
sonarrAPIKey="";
scanDatabasePath="";
arrOfSeriesId=();
arrOfProcess=();

trap end SIGINT; # Necessitate at least Bash 4 for ctrl c handling to work

findFilesToScan (){
  echo "[Info] Finding all elements";
  find $pathToFiles -type f -print | grep ".mp4\|.avi\|.mkv" > $scanDatabasePath;
  echo "[Info] All elements found";
  echo "[Info] Found $(cat $scanDatabasePath | wc -l) elements to transcode";
}

#usage transcode start end (lines of the database file)
transcode (){
  local start=$1;
  local end=$2;
  arrOfProcess[$i]=$BASHPID;
  echo "[Debug] pid : $BASHPID";
  echo "[Debug] Array of PIDS : $arrOfProcess";
  echo "[Debug] Thread number $3 trasncoding from line $start to $end";
  for el in $(sed -n "$start,${end}p" $scanDatabasePath)
  do
      if [[ !($el == *" aac"* || $el == *" AAC"* || $el == *".aac"* || $el == *".AAC"*) ]]
      then
          ext=$(echo $el | rev | cut -d "." -f 1 | rev);
          filename=$(echo $el | rev | cut -c $((${#ext}+2))- | rev);
          echo "[Info] Transcoding file : $el";
          if [[ $(ffmpeg -i "$el" -map 0 -acodec aac -metadata:s:a title= -vcodec copy -scodec srt "$filename transcodenow.$ext" 2>&1 | grep 'Subtitle encoding') == *"Subtitle encoding"* ]]
          then
              echo "[Error] Error with that file : $el";
              echo "[Error] Removing : $el";
              echo "[Error] Added problematic file to database";
              echo $el >> $pathOfFailedDatabase;
          fi
          echo "[Info] File : $el; transcoded";
          echo "";
          if [[ $(du -k "$filename transcodenow.$ext" | cut -d$'\t' -f 1) < 1000 ]]
          then
              echo "[Info] Size of $filename transcodenow.$ext : $(du -k "$filename transcodenow.$ext" | cut -d$'\t' -f 1)";
              echo "[Info] Deleting untranscoded file";
              rm "$filename transcodenow.$ext";
          else
              rm "$el";
              mv "$filename transcodenow.$ext" "$el";
              echo "[Info] Replacing by transcoded file";
              echo "";
              echo "";
              idOfSerie=$(curl -s "http://$serverIp:$serverPort/api/parse?path=$sonarrRootFolder/$(find $pathOfRootFolder -type f -printf '%P\n' | grep $(echo "$filename" | rev | cut -d "/" -f 1-3 | rev) | sed -r 's/ /%20/g')&apikey=$sonarrAPIKey" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data['episodes'][0]['seriesId'])");
              if [[ -n "${arrOfSeriesId[$idOfSerie]}" ]]
              then
                echo "[Info] Serie already added to array";
              else
                arrOfSeriesId[$idOfSerie]=$idOfSerie;
                echo "[Info] Element added";
                #sonarrScan $idOfSerie;
              fi
          fi
      fi
  done
  echo "[Debug] Thread number $3 ended";
}

#usage sonarrScan idOfSerie where idOfSerie is the id of the tv show given by sonarr
sonarrScan (){
  value=$1;
  echo "[Info] Sending scan request to sonarr for serie id : ${arrOfSeriesId[$value]}";
  idOfJob=$(curl -s -d "{'name' : 'RescanSeries', 'seriesId' : ${arrOfSeriesId[$value]}}" -H "Content-Type: application/json" -X POST "http://$serverIp:$serverPort/api/command?apikey=$sonarrAPIKey" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])");
  statusOfScan=$(curl -s "http://$serverIp:$serverPort/api/command/$idOfJob?apikey=$sonarrAPIKey" | python3 -c 'import sys, json; print(json.load(sys.stdin)["status"])');
  echo "[Info] Scan status : $statusOfScan for $value";
  while [ "$statusOfScan" != "completed" ]
  do
      statusOfScan=$(curl -s "http://$serverIp:$serverPort/api/command/$idOfJob?apikey=$sonarrAPIKey" | python3 -c 'import sys, json; print(json.load(sys.stdin)["status"])');
      sleep 1;
  done
  echo "[Info] Scan $statusOfScan for $value";
}

end (){
  for el in $arrOfProcess
  do
    echo "[Info] Killing process id : $el";
    kill -9 $el;
  done
}


findFilesToScan;

threads=2;
nbLines=$(cat $scanDatabasePath | wc -l);
offset=$(($(($nbLines / $threads)) + 1));
for i in $( seq 0 $(($threads - 1)) )
do
  transcode $((i * $offset + 1)) $(( $((i + 1)) * $offset)) $i &
done
echo $arrOfProcess;

wait;

echo "[Info] Transcodarr ended";
