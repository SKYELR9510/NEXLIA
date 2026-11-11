CREATE TABLE IF NOT EXISTS spam_numeros (
  numero      VARCHAR(15)  NOT NULL PRIMARY KEY,
  reportes    INT          NOT NULL DEFAULT 0,
  etiqueta    VARCHAR(60)  NOT NULL DEFAULT '',
  actualizado TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS spam_reportes (
  numero      VARCHAR(15)  NOT NULL,
  dispositivo VARCHAR(64)  NOT NULL,
  etiqueta    VARCHAR(60)  NOT NULL DEFAULT '',
  fecha       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (numero, dispositivo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Para marcar un numero a mano como spam confirmado:
-- INSERT INTO spam_numeros (numero, reportes, etiqueta) VALUES ('987654321', 99, 'ventas')
--   ON DUPLICATE KEY UPDATE reportes = 99;
