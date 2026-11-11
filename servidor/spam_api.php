<?php
// Base de datos de spam en línea para el marcador.
// Súbelo a tu hosting (con HTTPS), crea las tablas con schema.sql y completa estos datos.

const DB_HOST  = 'localhost';
const DB_NAME  = 'CAMBIAR_nombre_bd';
const DB_USER  = 'CAMBIAR_usuario';
const DB_PASS  = 'CAMBIAR_password';
const API_CLAVE = 'CAMBIAR_por_una_clave_larga'; // la misma que pones en la app

header('Content-Type: application/json; charset=utf-8');

function salir(array $data, int $code = 200): void {
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

$in = array_merge($_GET, $_POST);

if (!hash_equals(API_CLAVE, (string)($in['clave'] ?? ''))) {
    salir(['ok' => false, 'error' => 'clave incorrecta'], 403);
}

try {
    $pdo = new PDO(
        'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
        DB_USER, DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
    );
} catch (Throwable $e) {
    salir(['ok' => false, 'error' => 'sin conexion a la base de datos'], 500);
}

$accion = (string)($in['accion'] ?? '');
$numero = preg_replace('/\D+/', '', (string)($in['numero'] ?? ''));

switch ($accion) {
    case 'estado':
        $n = (int)$pdo->query('SELECT COUNT(*) FROM spam_numeros')->fetchColumn();
        salir(['ok' => true, 'numeros' => $n]);

    case 'consultar':
        if ($numero === '') salir(['ok' => false, 'error' => 'falta numero'], 400);
        $st = $pdo->prepare('SELECT reportes, etiqueta FROM spam_numeros WHERE numero = ?');
        $st->execute([$numero]);
        $row = $st->fetch();
        salir([
            'ok' => true,
            'reportes' => $row ? (int)$row['reportes'] : 0,
            'etiqueta' => $row ? (string)$row['etiqueta'] : '',
        ]);

    case 'reportar':
        $dispositivo = substr((string)($in['dispositivo'] ?? ''), 0, 64);
        $etiqueta = mb_substr(trim((string)($in['etiqueta'] ?? '')), 0, 60);
        if (strlen($numero) < 6 || strlen($numero) > 15 || $dispositivo === '') {
            salir(['ok' => false, 'error' => 'datos incompletos'], 400);
        }
        // Cada teléfono cuenta una sola vez por número.
        $st = $pdo->prepare('INSERT IGNORE INTO spam_reportes (numero, dispositivo, etiqueta) VALUES (?, ?, ?)');
        $st->execute([$numero, $dispositivo, $etiqueta]);
        if ($st->rowCount() > 0) {
            $up = $pdo->prepare(
                'INSERT INTO spam_numeros (numero, reportes, etiqueta) VALUES (?, 1, ?)
                 ON DUPLICATE KEY UPDATE reportes = reportes + 1,
                 etiqueta = IF(VALUES(etiqueta) <> "", VALUES(etiqueta), etiqueta)'
            );
            $up->execute([$numero, $etiqueta]);
        }
        salir(['ok' => true]);

    default:
        salir(['ok' => false, 'error' => 'accion desconocida'], 400);
}
