<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Settings
    |--------------------------------------------------------------------------
    |
    | Set some default values. It is possible to add all defines that can be set
    | in dompdf_config.inc.php. You can also override the whole config file.
    |
    */
    'show_warnings' => false,

    'public_path' => null,

    /*
    |--------------------------------------------------------------------------
    | Orientation
    |--------------------------------------------------------------------------
    |
    | The default paper orientation (portrait or landscape).
    |
    */
    'orientation' => 'portrait',

    /*
    |--------------------------------------------------------------------------
    | Defines
    |--------------------------------------------------------------------------
    |
    | The defines are used to set the default values for the dompdf options.
    |
    */
    'defines' => [
        /**
         * The location of the DOMPDF font directory
         */
        'DOMPDF_FONT_DIR' => storage_path('fonts/'),

        /**
         * The location of the DOMPDF font cache directory
         */
        'DOMPDF_FONT_CACHE' => storage_path('fonts/'),

        /**
         * The paper size (letter, legal, A4, etc.)
         */
        'DOMPDF_DEFAULT_PAPER_SIZE' => 'a4',

        /**
         * Whether to enable font subsetting
         */
        'DOMPDF_ENABLE_FONT_SUBSETTING' => false,

        /**
         * Whether to enable remote file access
         */
        'DOMPDF_ENABLE_REMOTE' => true,

        /**
         * A temporary directory for dompdf
         */
        'DOMPDF_TEMP_DIR' => sys_get_temp_dir(),

        /**
         * The log output file
         */
        'DOMPDF_LOG_OUTPUT_FILE' => '',

        /**
         * Whether to enable CSS float
         */
        'DOMPDF_ENABLE_CSS_FLOAT' => true,

        /**
         * Whether to enable HTML5 parser
         */
        'DOMPDF_ENABLE_HTML5PARSER' => true,
    ],

];
