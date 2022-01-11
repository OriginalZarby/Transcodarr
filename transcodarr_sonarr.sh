#! /bin/bash
IFS=$'\n';
pathOfFailedDatabase="";


transcodeSonarr (){
  local el=$1;
  if [[ !($el == "") ]] #*" aac"* || $el == *" AAC"* || $el == *".aac"* || $el == *".AAC"*) ]]
  then
    ext=$(echo $el | rev | cut -d "." -f 1 | rev);
    filename=$(echo $el | rev | cut -c $((${#ext}+2))- | rev);
    >&1 echo "[Info] Transcoding file : $el";
    if [[ $(ffmpeg -i "$el" -map 0 -acodec aac -metadata:s:a title= -vcodec copy -scodec srt "$filename transcodenow.$ext" 2>&1 | grep 'Subtitle encoding') == *"Subtitle encoding"* ]]
    then
      >&2 echo "[Error] Error with that file : $el";
      >&2 echo "[Error] Removing : $filename transcodenow.$ext";
      >&2 echo "[Error] Added problematic file to database";
      >&2 echo $el >> $pathOfFailedDatabase;
    else
      >&1 echo "[Info] File : $el; transcoded";
      >&1 echo "";
      if [[ $(du -k "$filename transcodenow.$ext" | cut -d$'\t' -f 1) < 1000 ]]
      then
        >&2 echo "[Error] Size of $filename transcodenow.$ext : $(du -k "$filename transcodenow.$ext" | cut -d$'\t' -f 1)";
        >&2 echo "[Error] Deleting untranscoded file";
        rm "$filename transcodenow.$ext";
      else
        rm "$el";
        mv "$filename transcodenow.$ext" "$el";
        >&1 echo "[Info] Replacing by transcoded file";
        >&1 echo "";
        >&1 echo "";
      fi
    fi
  fi
  >&1 echo "[Info] Done trancoding file";
}

>&2 echo "[Debug] $sonarr_episodefile_path";
>&2 echo "[Debug] ${sonarr_eventtype}";


if [ ${sonarr_eventtype} = "Test" ]; then
  >&2 echo "[Debug] Testing script";
  >&2 echo "[Info] Transcodarr ended";
  exit;
fi

if [ -n "$sonarr_episodefile_path" ]; then
  transcodeSonarr $sonarr_episodefile_path;
fi
>&1 echo "[Info] Transcodarr ended";
exit;
