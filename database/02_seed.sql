-- =====================================================================
--  Meu Virtual Nutri (MVN) - Dados de exemplo (seed)
--
--  Reproduz os valores exibidos no prototipo Figma:
--    * Peso atual ............ 68.1 kg
--    * Perdidos desde inicio . 2.4 kg  (70.5 -> 68.1)
--    * Meta .................. 65 kg   (3.1 kg restantes)
--    * Historico de peso ..... 68.1 / 68.7 / 69.2 ...
--
--  As datas sao RELATIVAS a CURDATE(), para que os filtros
--  "Semanal" e "Mensal" das telas sempre tenham dados, qualquer
--  que seja o dia em que o projeto for executado.
--
--  Modelagem do progresso: o paciente registra calorias/adesao
--  TODOS os dias, mas se pesa apenas uma vez por semana. Por isso
--  progresso.peso e NULL nos dias sem pesagem (a coluna aceita NULL).
--  As telas de peso filtram "peso IS NOT NULL".
--
--  Senha de todos os usuarios de teste: 123456
-- =====================================================================

USE MVNdb;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE refeicao_alimento;
TRUNCATE TABLE paciente_restricao;
TRUNCATE TABLE favoritos;
TRUNCATE TABLE notificacao;
TRUNCATE TABLE progresso;
TRUNCATE TABLE mensagem;
TRUNCATE TABLE consulta;
TRUNCATE TABLE refeicao;
TRUNCATE TABLE plano_alimentar;
TRUNCATE TABLE alimento;
TRUNCATE TABLE restricao;
TRUNCATE TABLE paciente;
TRUNCATE TABLE nutricionista;
TRUNCATE TABLE usuario;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------
-- USUARIOS  (senha em bcrypt = "123456")
-- ---------------------------------------------------------------
INSERT INTO usuario (id_usuario, nome, email, senha, telefone, tipo_usuario) VALUES
  (1, 'Dr. Gabriel',        'gabriel@mvn.com', '$2a$10$6snY9QBmRQatLNG0y58Hn.1C7VS8k5aSqKk09Do9VqJlbFiLB8zu6', '(19) 99888-1122', 'nutricionista'),
  (2, 'Ana Beatriz Souza',  'ana@mvn.com',     '$2a$10$6snY9QBmRQatLNG0y58Hn.1C7VS8k5aSqKk09Do9VqJlbFiLB8zu6', '(19) 99777-3344', 'paciente');

INSERT INTO nutricionista (id_nutricionista, id_usuario, crn, especializacao) VALUES
  (1, 1, 'CRN-3 45678', 'Nutricao Clinica');

-- peso_atual 68.10 / peso_meta 65.00  -> "Meta: 65kg (3.1kg restantes)"
INSERT INTO paciente
  (id_paciente, id_usuario, idade, peso_atual, altura, genero, meta, peso_meta, nivel_atividade, tipo_dieta)
VALUES
  (1, 2, 28, 68.10, 1.65, 'Feminino', 'Perda de peso', 65.00, 'moderado', 'Low carb');

-- ---------------------------------------------------------------
-- CHAT  (conversa do prototipo, tela 14)
-- ---------------------------------------------------------------
-- 1 = Dr. Gabriel (nutricionista)  |  2 = Ana Beatriz (paciente)
INSERT INTO mensagem (id_remetente, id_destinatario, mensagem, data_hora) VALUES
  (1, 2, 'ola bom dia! ja atualizei seu cardapio da semana!',
         TIMESTAMP(CURDATE(), '11:54:00')),
  (2, 1, 'oiii okei!',
         TIMESTAMP(CURDATE(), '12:09:00'));

-- ---------------------------------------------------------------
-- PROGRESSO - pesagens semanais (peso preenchido)
--   70.5 -> 68.1  = 2.4 kg perdidos desde o inicio
-- ---------------------------------------------------------------
INSERT INTO progresso (id_paciente, peso, consumo_calorico, aderencia_plano, data_registro) VALUES
  (1, 70.50, 2050.00, 78.00, DATE_SUB(CURDATE(), INTERVAL 28 DAY)),
  (1, 69.90, 1980.00, 82.00, DATE_SUB(CURDATE(), INTERVAL 21 DAY)),
  (1, 69.20, 1920.00, 88.00, DATE_SUB(CURDATE(), INTERVAL 14 DAY)),
  (1, 68.70, 1890.00, 91.00, DATE_SUB(CURDATE(), INTERVAL  7 DAY)),
  (1, 68.10, 1900.00, 94.00, CURDATE());

-- ---------------------------------------------------------------
-- PROGRESSO - registros diarios de calorias/adesao (peso NULL)
--   Alimenta o grafico "Consumo Calorico Semanal" (Seg..Dom)
-- ---------------------------------------------------------------
INSERT INTO progresso (id_paciente, peso, consumo_calorico, aderencia_plano, data_registro) VALUES
  (1, NULL, 1950.00, 90.00, DATE_SUB(CURDATE(), INTERVAL  1 DAY)),
  (1, NULL, 2100.00, 84.00, DATE_SUB(CURDATE(), INTERVAL  2 DAY)),
  (1, NULL, 1980.00, 92.00, DATE_SUB(CURDATE(), INTERVAL  3 DAY)),
  (1, NULL, 1850.00, 96.00, DATE_SUB(CURDATE(), INTERVAL  4 DAY)),
  (1, NULL, 2050.00, 87.00, DATE_SUB(CURDATE(), INTERVAL  5 DAY)),
  (1, NULL, 1930.00, 93.00, DATE_SUB(CURDATE(), INTERVAL  6 DAY)),
  (1, NULL, 1870.00, 95.00, DATE_SUB(CURDATE(), INTERVAL  8 DAY)),
  (1, NULL, 1990.00, 89.00, DATE_SUB(CURDATE(), INTERVAL  9 DAY)),
  (1, NULL, 2020.00, 86.00, DATE_SUB(CURDATE(), INTERVAL 10 DAY)),
  (1, NULL, 1880.00, 94.00, DATE_SUB(CURDATE(), INTERVAL 11 DAY)),
  (1, NULL, 1910.00, 91.00, DATE_SUB(CURDATE(), INTERVAL 12 DAY)),
  (1, NULL, 2060.00, 83.00, DATE_SUB(CURDATE(), INTERVAL 13 DAY)),
  (1, NULL, 1940.00, 90.00, DATE_SUB(CURDATE(), INTERVAL 15 DAY)),
  (1, NULL, 2000.00, 88.00, DATE_SUB(CURDATE(), INTERVAL 16 DAY)),
  (1, NULL, 1960.00, 92.00, DATE_SUB(CURDATE(), INTERVAL 17 DAY)),
  (1, NULL, 2080.00, 81.00, DATE_SUB(CURDATE(), INTERVAL 18 DAY)),
  (1, NULL, 1900.00, 93.00, DATE_SUB(CURDATE(), INTERVAL 19 DAY)),
  (1, NULL, 1870.00, 95.00, DATE_SUB(CURDATE(), INTERVAL 20 DAY)),
  (1, NULL, 2040.00, 85.00, DATE_SUB(CURDATE(), INTERVAL 22 DAY)),
  (1, NULL, 2010.00, 87.00, DATE_SUB(CURDATE(), INTERVAL 23 DAY)),
  (1, NULL, 1970.00, 89.00, DATE_SUB(CURDATE(), INTERVAL 24 DAY)),
  (1, NULL, 2090.00, 80.00, DATE_SUB(CURDATE(), INTERVAL 25 DAY)),
  (1, NULL, 1990.00, 86.00, DATE_SUB(CURDATE(), INTERVAL 26 DAY)),
  (1, NULL, 2030.00, 84.00, DATE_SUB(CURDATE(), INTERVAL 27 DAY));

-- ---------------------------------------------------------------
-- ALIMENTOS  (valores nutricionais por 100 g)
-- ---------------------------------------------------------------
INSERT INTO alimento (id_alimento, nome, calorias, proteinas, carboidratos, gorduras) VALUES
  ( 1, 'Aveia em flocos',            389.00, 16.90, 66.30,  6.90),
  ( 2, 'Leite desnatado',             35.00,  3.40,  5.00,  0.20),
  ( 3, 'Banana',                      89.00,  1.10, 22.80,  0.30),
  ( 4, 'Arroz branco cozido',        130.00,  2.70, 28.20,  0.30),
  ( 5, 'Feijao carioca cozido',       76.00,  4.80, 13.60,  0.50),
  ( 6, 'Peito de frango grelhado',   165.00, 31.00,  0.00,  3.60),
  ( 7, 'Brocolis cozido',             35.00,  2.40,  7.20,  0.40),
  ( 8, 'Azeite de oliva',            884.00,  0.00,  0.00,100.00),
  ( 9, 'Iogurte natural desnatado',   56.00,  5.30,  7.70,  0.20),
  (10, 'Maca',                        52.00,  0.30, 13.80,  0.20),
  (11, 'Castanha do Para',           656.00, 14.30, 12.30, 66.40),
  (12, 'Tilapia grelhada',           128.00, 26.00,  0.00,  2.70),
  (13, 'Batata doce cozida',          86.00,  1.60, 20.10,  0.10),
  (14, 'Pao integral',               247.00, 13.00, 41.00,  3.40);

-- ---------------------------------------------------------------
-- PLANO ALIMENTAR + REFEICOES (7 dias x 4 refeicoes = 28)
-- ---------------------------------------------------------------
INSERT INTO plano_alimentar (id_plano, id_paciente, id_nutricionista, nome_plano, objetivo) VALUES
  (1, 1, 1, 'Plano Low Carb - Marco', 'Reducao gradual de peso mantendo massa magra');

INSERT INTO refeicao (id_plano, horario, dia_semana)
SELECT 1, h.horario, d.dia
FROM (SELECT 'Segunda' AS dia UNION ALL SELECT 'Terca' UNION ALL SELECT 'Quarta'
      UNION ALL SELECT 'Quinta' UNION ALL SELECT 'Sexta' UNION ALL SELECT 'Sabado'
      UNION ALL SELECT 'Domingo') AS d
CROSS JOIN (SELECT '07:00:00' AS horario UNION ALL SELECT '12:00:00'
            UNION ALL SELECT '16:00:00' UNION ALL SELECT '19:30:00') AS h;

-- Composicao de cada refeicao (mesma estrutura em todos os dias da semana).
-- O backend calcula a media diaria agregando por dia_semana.
INSERT INTO refeicao_alimento (id_refeicao, id_alimento, quantidade)
SELECT r.id_refeicao, t.id_alimento, t.quantidade
FROM refeicao r
JOIN (
    -- Cafe da Manha (07:00)
    SELECT '07:00:00' AS horario,  1 AS id_alimento,  50.00 AS quantidade
    UNION ALL SELECT '07:00:00',  2, 200.00
    UNION ALL SELECT '07:00:00',  3, 100.00
    -- Almoco (12:00)
    UNION ALL SELECT '12:00:00',  4, 180.00
    UNION ALL SELECT '12:00:00',  5, 120.00
    UNION ALL SELECT '12:00:00',  6, 130.00
    UNION ALL SELECT '12:00:00',  7, 100.00
    UNION ALL SELECT '12:00:00',  8,  10.00
    -- Cafe da Tarde (16:00)
    UNION ALL SELECT '16:00:00',  9, 170.00
    UNION ALL SELECT '16:00:00', 10, 130.00
    UNION ALL SELECT '16:00:00', 11,  15.00
    -- Jantar (19:30)
    UNION ALL SELECT '19:30:00', 12, 120.00
    UNION ALL SELECT '19:30:00', 13, 200.00
    UNION ALL SELECT '19:30:00', 14,  40.00
    UNION ALL SELECT '19:30:00',  8,   8.00
) AS t ON r.horario = t.horario
WHERE r.id_plano = 1;

-- ---------------------------------------------------------------
-- RESTRICOES / FAVORITOS / CONSULTA / NOTIFICACAO
--   (nao usados pelas tres telas, mas mantem o banco coerente)
-- ---------------------------------------------------------------
INSERT INTO restricao (id_restricao, descricao) VALUES
  (1, 'Intolerancia a lactose'),
  (2, 'Alergia a frutos do mar'),
  (3, 'Doenca celiaca');

INSERT INTO paciente_restricao (id_paciente, id_restricao) VALUES (1, 1);

INSERT INTO favoritos (id_paciente, id_alimento) VALUES (1, 3), (1, 6), (1, 13);

INSERT INTO consulta (id_nutricionista, id_paciente, data, horario, status) VALUES
  (1, 1, DATE_ADD(CURDATE(), INTERVAL 7 DAY), '14:00:00', 'agendada'),
  (1, 1, DATE_SUB(CURDATE(), INTERVAL 21 DAY), '14:00:00', 'concluida');

INSERT INTO notificacao (id_paciente, titulo, descricao, horario, ativo) VALUES
  (1, 'Hora do almoco', 'Nao esqueca de registrar sua refeicao!',
      TIMESTAMP(CURDATE(), '12:00:00'), TRUE);
