#------------------------------------------------------------------------------------------------------------
# PROXY CHECKER SETTINGS
#------------------------------------------------------------------------------------------------------------
our %mode_config = (
    #-- В какой тред и на какой борде пытаемся постить
    post_cnf => {
        board      => 'hr', 
        thread     => 1,
        email      => "",
        name       => "",
        subject    => "",
        password   => "fNfR3",
    },
    max_thrs   => 10,
    timeout    => 60,
    msg_data   => $msg,
    img_data   => $img,
);
 
