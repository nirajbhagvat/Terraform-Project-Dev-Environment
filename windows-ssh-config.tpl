add-content -path c:/users/admin/.ssh/config -value @'

Host ${hostname}
    hostName ${hostname}
    User ${user}
    identityFile ${identityfile}
'@