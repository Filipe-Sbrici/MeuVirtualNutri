-- =====================================================================
--  Meu Virtual Nutri (MVN) - Esquema do banco de dados
--  Base: "banco do tcc.txt" (estrutura original preservada)
--
--  Correcoes/adicoes em relacao ao arquivo original:
--    1. Removido o token solto "tcc" dentro de CREATE TABLE paciente
--       (linha 44 do original), que impedia a execucao do script.
--    2. Adicionada a coluna paciente.peso_meta (DECIMAL(5,2)).
--       Justificativa: a tela de Progresso exibe "Meta: 65kg
--       (3.1kg restantes)". A coluna original `meta` e VARCHAR(150) e
--       guarda o objetivo textual ("perda de peso"), nao um valor
--       numerico. Optou-se por UMA coluna nova numa tabela existente
--       em vez de criar tabelas novas.
--    3. Adicionado ENGINE/CHARSET explicitos e indices de apoio.
--
--  Nenhuma tabela nova foi criada: as tres telas usam apenas
--  usuario, nutricionista, paciente, mensagem, progresso,
--  plano_alimentar, refeicao, refeicao_alimento e alimento.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS MVNdb
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;
USE MVNdb;

-- ==========================
-- USUARIO
-- ==========================
CREATE TABLE IF NOT EXISTS usuario (
    id_usuario INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    senha VARCHAR(255) NOT NULL,
    telefone VARCHAR(20),
    tipo_usuario ENUM('nutricionista','paciente') NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==========================
-- NUTRICIONISTA
-- ==========================
CREATE TABLE IF NOT EXISTS nutricionista (
    id_nutricionista INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL UNIQUE,
    crn VARCHAR(20) NOT NULL UNIQUE,
    especializacao VARCHAR(100),

    CONSTRAINT fk_nutri_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES usuario(id_usuario)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==========================
-- PACIENTE
-- ==========================
CREATE TABLE IF NOT EXISTS paciente (
    id_paciente INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL UNIQUE,
    idade INT,
    peso_atual DECIMAL(5,2),
    altura DECIMAL(4,2),
    genero VARCHAR(20),
    meta VARCHAR(150),
    peso_meta DECIMAL(5,2),          -- adicao (ver cabecalho, item 2 e secao MIGRACOES)
    nivel_atividade VARCHAR(50),
    tipo_dieta VARCHAR(100),

    CONSTRAINT fk_paciente_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES usuario(id_usuario)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==========================
-- CONSULTA
-- ==========================
CREATE TABLE IF NOT EXISTS consulta (
    id_consulta INT AUTO_INCREMENT PRIMARY KEY,
    id_nutricionista INT NOT NULL,
    id_paciente INT NOT NULL,
    data DATE NOT NULL,
    horario TIME NOT NULL,
    status VARCHAR(30),

    CONSTRAINT fk_consulta_nutri
        FOREIGN KEY (id_nutricionista)
        REFERENCES nutricionista(id_nutricionista),

    CONSTRAINT fk_consulta_paciente
        FOREIGN KEY (id_paciente)
        REFERENCES paciente(id_paciente)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==========================
-- CHAT / MENSAGENS
-- ==========================
CREATE TABLE IF NOT EXISTS mensagem (
    id_mensagem INT AUTO_INCREMENT PRIMARY KEY,
    id_remetente INT NOT NULL,
    id_destinatario INT NOT NULL,
    mensagem TEXT NOT NULL,
    data_hora DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_msg_remetente
        FOREIGN KEY (id_remetente)
        REFERENCES usuario(id_usuario),

    CONSTRAINT fk_msg_destinatario
        FOREIGN KEY (id_destinatario)
        REFERENCES usuario(id_usuario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Indice de apoio: a tela de Chat busca a conversa entre dois usuarios
-- ordenada por data_hora. (Criado na secao MIGRACOES, ao final.)

-- ==========================
-- PLANO ALIMENTAR
-- ==========================
CREATE TABLE IF NOT EXISTS plano_alimentar (
    id_plano INT AUTO_INCREMENT PRIMARY KEY,
    id_paciente INT NOT NULL,
    id_nutricionista INT NOT NULL,
    nome_plano VARCHAR(100),
    objetivo TEXT,

    CONSTRAINT fk_plano_paciente
        FOREIGN KEY (id_paciente)
        REFERENCES paciente(id_paciente),

    CONSTRAINT fk_plano_nutricionista
        FOREIGN KEY (id_nutricionista)
        REFERENCES nutricionista(id_nutricionista)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==========================
-- REFEICAO
-- ==========================
CREATE TABLE IF NOT EXISTS refeicao (
    id_refeicao INT AUTO_INCREMENT PRIMARY KEY,
    id_plano INT NOT NULL,
    horario TIME,
    dia_semana VARCHAR(15),

    CONSTRAINT fk_refeicao_plano
        FOREIGN KEY (id_plano)
        REFERENCES plano_alimentar(id_plano)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==========================
-- ALIMENTO
-- ==========================
CREATE TABLE IF NOT EXISTS alimento (
    id_alimento INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    calorias DECIMAL(8,2),
    proteinas DECIMAL(8,2),
    carboidratos DECIMAL(8,2),
    gorduras DECIMAL(8,2)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==========================
-- REFEICAO_ALIMENTO
-- ==========================
CREATE TABLE IF NOT EXISTS refeicao_alimento (
    id_refeicao INT NOT NULL,
    id_alimento INT NOT NULL,
    quantidade DECIMAL(8,2),

    PRIMARY KEY(id_refeicao, id_alimento),

    CONSTRAINT fk_ra_refeicao
        FOREIGN KEY (id_refeicao)
        REFERENCES refeicao(id_refeicao)
        ON DELETE CASCADE,

    CONSTRAINT fk_ra_alimento
        FOREIGN KEY (id_alimento)
        REFERENCES alimento(id_alimento)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==========================
-- FAVORITOS
-- ==========================
CREATE TABLE IF NOT EXISTS favoritos (
    id_paciente INT NOT NULL,
    id_alimento INT NOT NULL,

    PRIMARY KEY(id_paciente, id_alimento),

    CONSTRAINT fk_fav_paciente
        FOREIGN KEY (id_paciente)
        REFERENCES paciente(id_paciente)
        ON DELETE CASCADE,

    CONSTRAINT fk_fav_alimento
        FOREIGN KEY (id_alimento)
        REFERENCES alimento(id_alimento)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==========================
-- RESTRICOES
-- ==========================
CREATE TABLE IF NOT EXISTS restricao (
    id_restricao INT AUTO_INCREMENT PRIMARY KEY,
    descricao VARCHAR(150) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==========================
-- PACIENTE_RESTRICAO
-- ==========================
CREATE TABLE IF NOT EXISTS paciente_restricao (
    id_paciente INT NOT NULL,
    id_restricao INT NOT NULL,

    PRIMARY KEY(id_paciente, id_restricao),

    CONSTRAINT fk_pr_paciente
        FOREIGN KEY (id_paciente)
        REFERENCES paciente(id_paciente)
        ON DELETE CASCADE,

    CONSTRAINT fk_pr_restricao
        FOREIGN KEY (id_restricao)
        REFERENCES restricao(id_restricao)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==========================
-- PROGRESSO
-- ==========================
CREATE TABLE IF NOT EXISTS progresso (
    id_progresso INT AUTO_INCREMENT PRIMARY KEY,
    id_paciente INT NOT NULL,
    peso DECIMAL(5,2),
    consumo_calorico DECIMAL(8,2),
    aderencia_plano DECIMAL(5,2),
    data_registro DATE,

    CONSTRAINT fk_progresso_paciente
        FOREIGN KEY (id_paciente)
        REFERENCES paciente(id_paciente)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Indice de apoio: telas de Progresso/Evolucao leem series temporais
-- por paciente ordenadas por data. (Criado na secao MIGRACOES, ao final.)

-- ==========================
-- NOTIFICACOES
-- ==========================
CREATE TABLE IF NOT EXISTS notificacao (
    id_notificacao INT AUTO_INCREMENT PRIMARY KEY,
    id_paciente INT NOT NULL,
    titulo VARCHAR(100),
    descricao TEXT,
    horario DATETIME,
    ativo BOOLEAN DEFAULT TRUE,

    CONSTRAINT fk_notificacao_paciente
        FOREIGN KEY (id_paciente)
        REFERENCES paciente(id_paciente)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
--  MIGRACOES IDEMPOTENTES
--
--  Permite rodar este script tanto num banco novo quanto num banco
--  MVNdb que ja existia (criado a partir do arquivo original). Os
--  CREATE TABLE acima usam IF NOT EXISTS e portanto NAO alteram
--  tabelas preexistentes -- por isso a coluna e os indices novos
--  precisam ser aplicados aqui.
--
--  Compativel com MySQL 5.7+/8.x e MariaDB 10.x (nao usa a sintaxe
--  "ADD COLUMN IF NOT EXISTS", que so existe no MariaDB).
-- =====================================================================

-- --- paciente.peso_meta -------------------------------------------------
SET @existe_peso_meta = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME   = 'paciente'
       AND COLUMN_NAME  = 'peso_meta'
);
SET @ddl = IF(@existe_peso_meta = 0,
    'ALTER TABLE paciente ADD COLUMN peso_meta DECIMAL(5,2) NULL AFTER meta',
    'DO 0');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- --- indice da conversa do chat ----------------------------------------
SET @existe_idx_msg = (
    SELECT COUNT(*) FROM information_schema.STATISTICS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME   = 'mensagem'
       AND INDEX_NAME   = 'idx_msg_conversa'
);
SET @ddl = IF(@existe_idx_msg = 0,
    'CREATE INDEX idx_msg_conversa ON mensagem (id_remetente, id_destinatario, data_hora)',
    'DO 0');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- --- indice da serie temporal de progresso -----------------------------
SET @existe_idx_prog = (
    SELECT COUNT(*) FROM information_schema.STATISTICS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME   = 'progresso'
       AND INDEX_NAME   = 'idx_progresso_paciente_data'
);
SET @ddl = IF(@existe_idx_prog = 0,
    'CREATE INDEX idx_progresso_paciente_data ON progresso (id_paciente, data_registro)',
    'DO 0');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

