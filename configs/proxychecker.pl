#------------------------------------------------------------------------------------------------------------
# PROXY CHECKER SETTINGS
#------------------------------------------------------------------------------------------------------------
our %mode_config = (
    #-- В какой тред и на какой борде пытаемся постить. В общем, похуй.
    post_cnf => {
        board      => 'b',
        thread     => 0,
        email      => "",
        name       => "",
        subject    => "",
        password   => "fNfR3",
    },
    max_thrs   => 100,
    timeout    => 160,
    msg_data   => $msg,
    img_data   => $img,
);
 
