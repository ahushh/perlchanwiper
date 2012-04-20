#------------------------------------------------------------------------------------------------------------
# DELETE SETTINGS
#------------------------------------------------------------------------------------------------------------
my $find = {
    board          => 'b',           #-- доска, на которой искать посты
    #by_id       => [1,2,3],       #-- вручную задать номера постов/тредов
    # regexp        => '<div class="postmessage">\s*</div>',         #-- фильтровать найденные посты по рэгкспу
    regexp => 'test',
    threads      => [10120554],           #-- искать посты в тредах
    # pages         => [0],        #-- искать и удалять треды на страницах
    # in_found_thrs => '.*',  #-- искать и удалять посты в тредах, найденных на страницах 'pages' и отфильтрованных заданным регэкспом
};
our %mode_config = (
    find           => $find,
    password       => "fNfR3",
    board          => 'b',           #-- доска, с которой удалять сообщения
    max_del_thrs   => 1,       #-- максимально количество запущенных потоков
    delete_timeout => 60,      #-- таймаут
);
