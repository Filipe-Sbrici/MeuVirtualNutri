/// Respostas reais da API, capturadas de um Firestore com o seed
/// carregado (equivalentes aos antigos fixtures MySQL).
///
/// Servem para exercitar as telas exatamente com o JSON que o backend
/// produz, sem precisar do servidor no ar durante os testes.
library;

const String kUidNutri = 'demo_nutri_a1b2c3';
const String kUidPaciente = 'demo_pac_d4e5f6';

const String kLoginJson =
    '{"sucesso":true,"dados":{"idUsuario":"$kUidPaciente",'
    '"uid":"$kUidPaciente","idPaciente":"$kUidPaciente",'
    '"nome":"Ana Beatriz Souza","email":"ana@mvn.com",'
    '"telefone":"(19) 99777-3344","tipoUsuario":"paciente",'
    '"onboardingCompleto":true,"tutorialVisto":true}}';

const String kContatoJson =
    '{"sucesso":true,"dados":{"idUsuario":"$kUidNutri",'
    '"idNutricionista":"$kUidNutri",'
    '"nome":"Dr. Gabriel","crn":"CRN-3 45678",'
    '"especializacao":"Nutricao Clinica","papel":"Nutricionista"}}';

const String kConversaJson =
    '{"sucesso":true,"dados":{"contato":{"idUsuario":"$kUidNutri",'
    '"uid":"$kUidNutri","nome":"Dr. Gabriel",'
    '"tipoUsuario":"nutricionista","papel":"Nutricionista"},"mensagens":['
    '{"idMensagem":"msg001","idRemetente":"$kUidNutri",'
    '"idDestinatario":"$kUidPaciente",'
    '"nomeRemetente":"Dr. Gabriel",'
    '"mensagem":"ola bom dia! ja atualizei seu cardapio da semana!",'
    '"dataHora":"2026-08-16T11:54:00","ehMinha":false},'
    '{"idMensagem":"msg002","idRemetente":"$kUidPaciente",'
    '"idDestinatario":"$kUidNutri",'
    '"nomeRemetente":"Ana Beatriz Souza","mensagem":"oiii okei!",'
    '"dataHora":"2026-08-16T12:09:00","ehMinha":true}]}}';

/// Resposta do POST /api/chat/mensagens.
const String kMensagemCriadaJson =
    '{"sucesso":true,"dados":{"idMensagem":"msg003",'
    '"idRemetente":"$kUidPaciente","idDestinatario":"$kUidNutri",'
    '"nomeRemetente":"Ana Beatriz Souza",'
    '"mensagem":"obrigada!","dataHora":"2026-08-16T19:23:12","ehMinha":true}}';

const String kProgressoJson =
    '{"sucesso":true,"dados":{"paciente":{"uid":"$kUidPaciente",'
    '"nome":"Ana Beatriz Souza","objetivo":"Perda de peso",'
    '"tipoDieta":"Low carb"},"resumo":{"pesoAtual":68.1,"pesoInicial":70.5,'
    '"pesoMeta":65,"diferenca":2.4,"sentido":"perda",'
    '"rotuloDiferenca":"Perdidos desde o inicio","restantesParaMeta":3.1,'
    '"percentualMeta":43.6,"dataPrimeiroRegistro":"2026-07-19",'
    '"dataUltimoRegistro":"2026-08-16"},"historico":['
    '{"idProgresso":"2026-08-16","peso":68.1,"dataRegistro":"2026-08-16","aderenciaPlano":94},'
    '{"idProgresso":"2026-08-09","peso":68.7,"dataRegistro":"2026-08-09","aderenciaPlano":91},'
    '{"idProgresso":"2026-08-02","peso":69.2,"dataRegistro":"2026-08-02","aderenciaPlano":88},'
    '{"idProgresso":"2026-07-26","peso":69.9,"dataRegistro":"2026-07-26","aderenciaPlano":82},'
    '{"idProgresso":"2026-07-19","peso":70.5,"dataRegistro":"2026-07-19","aderenciaPlano":78}],'
    '"hoje":{"dataRegistro":"2026-08-16","coposAgua":3,"humor":"bom"}}}';

/// Perfil de sessao COM os dados clinicos (GET /api/auth/perfil).
/// A tela de Perfil depende deles para o IMC e as restricoes.
const String kPerfilClinicoJson =
    '{"sucesso":true,"dados":{"idUsuario":"$kUidPaciente",'
    '"uid":"$kUidPaciente","idPaciente":"$kUidPaciente",'
    '"nome":"Ana Beatriz Souza","email":"ana@mvn.com",'
    '"telefone":"(19) 99777-3344","tipoUsuario":"paciente",'
    '"onboardingCompleto":true,"tutorialVisto":true,'
    '"idade":31,"pesoAtual":68.1,"pesoMeta":65,"altura":1.65,'
    '"genero":"Feminino","meta":"Perda de peso","nivelAtividade":"moderado",'
    '"tipoDieta":"Low carb","alimentosFavoritos":["frango"],'
    '"alimentosRejeitados":["peixe"],'
    '"restricoes":["Intolerancia a lactose"],'
    '"condicoesMedicas":["Hipertensao"]}}';

/// Resposta do PUT /api/perfil/perfil (envelope com `perfil`).
const String kPerfilAtualizadoJson =
    '{"sucesso":true,"dados":{"perfil":{"uid":"$kUidPaciente",'
    '"nome":"Ana B. Souza","email":"ana@mvn.com","tipoUsuario":"paciente",'
    '"onboardingCompleto":true,"tutorialVisto":true,'
    '"idade":31,"pesoAtual":67.5,"pesoMeta":65,"altura":1.65,'
    '"restricoes":[],"condicoesMedicas":[]}}}';

/// Resposta do POST/DELETE de peso: `registro` ao lado de `dados`.
const String kPesoRegistradoJson =
    '{"sucesso":true,"registro":{"idProgresso":"2026-08-23","atualizado":false,'
    '"peso":67.8,"dataRegistro":"2026-08-23"},"dados":{"paciente":'
    '{"uid":"$kUidPaciente","nome":"Ana Beatriz Souza",'
    '"objetivo":"Perda de peso","tipoDieta":"Low carb"},"resumo":'
    '{"pesoAtual":67.8,"pesoInicial":70.5,"pesoMeta":65,"diferenca":2.7,'
    '"sentido":"perda","rotuloDiferenca":"Perdidos desde o inicio",'
    '"restantesParaMeta":2.8,"percentualMeta":49.1,'
    '"dataPrimeiroRegistro":"2026-07-19","dataUltimoRegistro":"2026-08-23"},'
    '"historico":[{"idProgresso":"2026-08-23","peso":67.8,"dataRegistro":"2026-08-23",'
    '"aderenciaPlano":null},{"idProgresso":"2026-08-16","peso":68.1,'
    '"dataRegistro":"2026-08-16","aderenciaPlano":94}]}}';

const String kEvolucaoJson =
    '{"sucesso":true,"dados":{"paciente":{"uid":"$kUidPaciente",'
    '"nome":"Ana Beatriz Souza","objetivo":"Perda de peso"},'
    '"periodo":"mensal","metaCalorica":1773,'
    '"plano":{"idPlano":"plano_demo_ana","nomePlano":"Plano Low Carb Semanal"},'
    '"evolucaoPeso":{"pontos":['
    '{"data":"2026-07-19","peso":70.5},{"data":"2026-07-26","peso":69.9},'
    '{"data":"2026-08-02","peso":69.2},{"data":"2026-08-09","peso":68.7},'
    '{"data":"2026-08-16","peso":68.1}],'
    '"minimo":67.6,"maximo":71,"variacao":2.4},'
    '"consumoSemanal":{"barras":['
    '{"rotulo":"Seg","consumido":1930,"meta":1773,"data":"2026-08-10"},'
    '{"rotulo":"Ter","consumido":2050,"meta":1773,"data":"2026-08-11"},'
    '{"rotulo":"Qua","consumido":1850,"meta":1773,"data":"2026-08-12"},'
    '{"rotulo":"Qui","consumido":1980,"meta":1773,"data":"2026-08-13"},'
    '{"rotulo":"Sex","consumido":2100,"meta":1773,"data":"2026-08-14"},'
    '{"rotulo":"Sab","consumido":1950,"meta":1773,"data":"2026-08-15"},'
    '{"rotulo":"Dom","consumido":1900,"meta":1773,"data":"2026-08-16"}],'
    '"mediaConsumida":1966,"meta":1773,"maximoEixo":2100},'
    '"macronutrientes":{"aderenciaMedia":90.9,"origemMeta":"plano_alimentar",'
    '"itens":['
    '{"chave":"proteinas","rotulo":"Proteina","consumido":110,"meta":121,'
    '"unidade":"g","percentual":90.9},'
    '{"chave":"carboidratos","rotulo":"Carboidrato","consumido":209,'
    '"meta":230,"unidade":"g","percentual":90.9},'
    '{"chave":"gorduras","rotulo":"Gordura","consumido":40,"meta":44,'
    '"unidade":"g","percentual":90.9}]}}}';

/// Cardapio de hoje com checklist parcial.
const String kCardapioHojeJson =
    '{"sucesso":true,"dados":{"plano":{"idPlano":"plano_demo_ana",'
    '"nomePlano":"Plano Low Carb Semanal","objetivo":"Perda de peso"},'
    '"dia":"segunda","refeicoes":['
    '{"id":"segunda_cafeManha","dia":"segunda","tipo":"cafeManha",'
    '"rotuloDia":"Segunda","rotuloTipo":"Cafe da Manha","horario":"07:30",'
    '"nomeReceita":"Mingau de aveia com banana","calorias":320,'
    '"proteinas":18,"carboidratos":42,"gorduras":6,"concluida":false},'
    '{"id":"segunda_almoco","dia":"segunda","tipo":"almoco",'
    '"rotuloDia":"Segunda","rotuloTipo":"Almoco","horario":"12:30",'
    '"nomeReceita":"Frango grelhado com brocolis","calorias":420,'
    '"proteinas":52,"carboidratos":30,"gorduras":10,"concluida":true}],'
    '"resumo":{"total":2,"concluidas":1,"percentual":50,'
    '"totalCalorias":740,"caloriasConcluidas":420}}}';

/// Resposta de login/perfil do Nutricionista.
const String kLoginNutriJson =
    '{"sucesso":true,"dados":{"idUsuario":"$kUidNutri",'
    '"uid":"$kUidNutri","idNutricionista":"$kUidNutri",'
    '"nome":"Dr. Gabriel","email":"gabriel@mvn.com",'
    '"crn":"CRN-3 45678","tipoUsuario":"nutricionista",'
    '"onboardingCompleto":true,"tutorialVisto":true}}';

/// Resposta de cadastro de Paciente.
const String kCadastroPacienteJson =
    '{"sucesso":true,"dados":{"idUsuario":"novo_uid_10",'
    '"uid":"novo_uid_10","idPaciente":"novo_uid_10",'
    '"nome":"Novo Paciente","email":"novo@paciente.com",'
    '"tipoUsuario":"paciente","onboardingCompleto":false,'
    '"tutorialVisto":false}}';

/// Resposta de cadastro de Nutricionista.
const String kCadastroNutriJson =
    '{"sucesso":true,"dados":{"idUsuario":"novo_uid_11",'
    '"uid":"novo_uid_11","idNutricionista":"novo_uid_11",'
    '"nome":"Dra. Julia","email":"julia@nutri.com",'
    '"crn":"CRN-3 99999","tipoUsuario":"nutricionista",'
    '"onboardingCompleto":true,"tutorialVisto":false}}';

/// Envelope de erro da API (400/401/404).
const String kErroJson =
    '{"sucesso":false,"erro":{"mensagem":"Paciente 99 nao encontrado."}}';
