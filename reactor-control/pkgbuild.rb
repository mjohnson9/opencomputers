id :'reactor-control'
name 'Reactor control'
description 'Controls a single Big Reactors reactor'

install 'bin/reactor-control.lua' => '/bin'

authors 'Michael Johnson'

depend libpid: '/'
