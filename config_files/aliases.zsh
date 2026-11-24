alias ssh="kitten ssh"
# alias tmux='TERM=tmux-256color tmux'
alias sshat='ssh -L 8081:127.0.0.1:8081 -Y sberger@10.5.120.1'
alias sshat1='ssh -L 8081:127.0.0.1:8081 -Y sberger@10.5.120.1'
alias sshat2='ssh -L 8082:127.0.0.1:8082 -Y sberger@10.5.120.2'
alias sshi6='ssh -L 8083:127.0.0.1:8083 -Y cadmium'
alias icat='kitten icat'
alias cat='bat'
alias apptalk-db='minikube start && kubectl port-forward -n apptalk-dev svc/apptalk-datastores-postgres 5432:5432 &'
alias yay-update='yay -Syu --noconfirm'

# scp functions #
scpfromat(){
  scp -r sberger@10.5.120.1:$1 $PWD/$2
}

scptoat(){
  scp -r $PWD/$1 sberger@10.5.120.1:$2
}

scpfromi6(){
  scp -r berger@cadmium.informatik.rwth-aachen.de:$1 $PWD/$2
}

scptoi6(){
  scp -r $PWD/$1 berger@mangan.informatik.rwth-aachen.de:$2
}

# jump back #
upto(){
  if [ -z $1 ]; then
    cd
  else
    fullD=$(pwd); i=2
    predir="/$(echo $fullD | cut -d '/' -f 1,2)"
    while [$predir != $fullD ]; do
      if echo $predir | grep -q $1; then
        break
      else
        i=$((i+1))
        predir="$predir/$(echo $fullD | cut -d '/' -f $i)"
      fi
    done
    cd $predir
  fi
}
