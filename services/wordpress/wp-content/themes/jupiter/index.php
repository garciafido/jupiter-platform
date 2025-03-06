<?php
/*
Template Name: Home Jupiter
*/
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>JUPITER - Plataforma de Gestión Musical</title>
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@300;400;700;900&display=swap" rel="stylesheet">
    <link rel="icon" type="image/x-icon" href="<?php echo get_template_directory_uri(); ?>/custom-favicon.ico?v=1">
    <link rel="shortcut icon" href="<?php echo get_template_directory_uri(); ?>/custom-favicon.ico?v=1">
    <?php wp_head(); ?>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: 'Montserrat', sans-serif;
        }

        body {
            background-color: #181818;
            color: #ffffff;
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
        }

        .content {
            text-align: center;
            padding: 1rem;
        }

        .logo {
            width: 100%;
            max-width: 300px;
            height: auto;
            margin-bottom: 2rem;
        }

        .title {
            color: #4040B0;
            font-size: 5rem;
            font-weight: 900;
            letter-spacing: 1.2rem;
            margin-bottom: 1.5rem;
            text-transform: uppercase;
            -webkit-text-stroke: 1px #4040B0;
            text-shadow: 2px 2px 4px rgba(64, 64, 176, 0.3);
        }

        .subtitle {
            color: #ffffff;
            font-size: 1.5rem;
            letter-spacing: 0.3rem;
            font-weight: 300;
            opacity: 0.9;
        }

        @media (max-width: 768px) {
            .logo {
                max-width: 200px;
                margin-bottom: 1.5rem;
            }

            .title {
                font-size: 3rem;
                letter-spacing: 0.8rem;
            }

            .subtitle {
                font-size: 1.2rem;
                letter-spacing: 0.2rem;
            }
        }

        @media (max-width: 480px) {
            .logo {
                max-width: 150px;
                margin-bottom: 1rem;
            }

            .title {
                font-size: 2rem;
                letter-spacing: 0.5rem;
            }

            .subtitle {
                font-size: 0.9rem;
                letter-spacing: 0.1rem;
            }

            .content {
                padding: 0.5rem;
            }
        }
    </style>
</head>
<body>
    <div class="content">
        <img src="<?php echo get_template_directory_uri(); ?>/logo1.png" alt="Jupiter Logo" class="logo">
        <h1 class="title">J U P I T E R</h1>
        <p class="subtitle">Plataforma de Gestión Musical</p>
    </div>
    <?php wp_footer(); // Recomendado para compatibilidad con WordPress ?>
</body>
</html>