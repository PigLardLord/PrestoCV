/// The closed vocabulary of Portuguese (ADR 0023), written as `DescriptionText.normalized` writes a word: lower case,
/// without accents, an elided article as a word of its own; but for the forms of to be and the auxiliaries, which keep them.
extension Vocabulary {
    static let portuguese = Words(
        /// Articles, prepositions, pronouns, auxiliaries, conjunctions and subordinators.
        function: """
        a ainda alem algum alguma algumas alguns antes ao aos apos aquela aquelas aquele aqueles aqui aquilo as assim
        ate cada com como conforme contra contudo cuja cujo d da das de depois desde do dos dum duma durante e em
        embora enquanto entao entre era eram eramos eras es essa essas esse esses esta estado estamos estao estar
        estas estava estavam este estes esteve estive estiveram estou eu faco faz fazem fazemos fazendo fazer feito
        fez fiz fizemos fizeram foi fomos foram foste fui ha haver havia houve isso isto ja l la logo m mais mas me
        mesma mesmas mesmo mesmos meu meus mim minha minhas muito na nas no nos nossa nossas nosso nossos num numa
        numas nuns o onde os ou outra outras outro outros para pela pelas pelo pelos perante por porem porque quais
        qual quando que quem s sao segundo sempre sendo ser sido sobre somos sou tambem tao te tem temos tendo tenho
        tens ter teu teve ti tido tinha tinham tinhamos tinhas tive tiveram toda todas todo todos tu tua um uma umas
        uns varias varios vos
        """,
        /// Verbs of a CV: their inflected forms, the infinitives set apart.
        verbs: """
        acompanha acompanhada acompanhadas acompanhado acompanhados acompanhais acompanham acompanhamos acompanhando
        acompanharam acompanhas acompanhaste acompanhastes acompanhava acompanhavam acompanhavamos acompanhavas
        acompanhaveis acompanhei acompanho acompanhou administra administrada administradas administrado administrados
        administrais administram administramos administrando administraram administras administraste administrastes
        administrava administravam administravamos administravas administraveis administrei administro administrou
        ajuda ajudada ajudadas ajudado ajudados ajudais ajudam ajudamos ajudando ajudaram ajudas ajudaste ajudastes
        ajudava ajudavam ajudavamos ajudavas ajudaveis ajudei ajudo ajudou analisa analisada analisadas analisado
        analisados analisais analisam analisamos analisando analisaram analisas analisaste analisastes analisava
        analisavam analisavamos analisavas analisaveis analisei analiso analisou aprende aprendeis aprendem aprendemos
        aprendendo aprenderam aprendes aprendeste aprendestes aprendeu aprendi aprendia aprendiam aprendiamos
        aprendias aprendida aprendidas aprendido aprendidos aprendieis aprendo apresenta apresentada apresentadas
        apresentado apresentados apresentais apresentam apresentamos apresentando apresentaram apresentas apresentaste
        apresentastes apresentava apresentavam apresentavamos apresentavas apresentaveis apresentei apresento
        apresentou assiste assistem assistes assisti assistia assistiam assistiamos assistias assistida assistidas
        assistido assistidos assistieis assistimos assistindo assistiram assistis assististe assististes assistiu
        assisto atende atendeis atendem atendemos atendendo atenderam atendes atendeste atendestes atendeu atendi
        atendia atendiam atendiamos atendias atendida atendidas atendido atendidos atendieis atendo atua atuada
        atuadas atuado atuados atuais atuam atuamos atuando atuaram atuas atuaste atuastes atuava atuavam atuavamos
        atuavas atuaveis atuei atuo atuou colabora colaborada colaboradas colaborado colaborados colaborais colaboram
        colaboramos colaborando colaboraram colaboras colaboraste colaborastes colaborava colaboravam colaboravamos
        colaboravas colaboraveis colaborei colaboro colaborou comeca comecada comecadas comecado comecados comecais
        comecam comecamos comecando comecaram comecas comecaste comecastes comecava comecavam comecavamos comecavas
        comecaveis comecei comeco comecou completa completada completadas completado completados completais completam
        completamos completando completaram completas completaste completastes completava completavam completavamos
        completavas completaveis completei completo completou conclui concluido concluindo concluiu concluo contrata
        contratada contratadas contratado contratados contratais contratam contratamos contratando contrataram
        contratas contrataste contratastes contratava contratavam contratavamos contratavas contrataveis contratei
        contrato contratou controla controlada controladas controlado controlados controlais controlam controlamos
        controlando controlaram controlas controlaste controlastes controlava controlavam controlavamos controlavas
        controlaveis controlei controlo controlou coordena coordenada coordenadas coordenado coordenados coordenais
        coordenam coordenamos coordenando coordenaram coordenas coordenaste coordenastes coordenava coordenavam
        coordenavamos coordenavas coordenaveis coordenei coordeno coordenou cozinha cozinhada cozinhadas cozinhado
        cozinhados cozinhais cozinham cozinhamos cozinhando cozinharam cozinhas cozinhaste cozinhastes cozinhava
        cozinhavam cozinhavamos cozinhavas cozinhaveis cozinhei cozinho cozinhou cria criada criadas criado criados
        criais criam criamos criando criaram crias criaste criastes criava criavam criavamos criavas criaveis criei
        crio criou cuida cuidada cuidadas cuidado cuidados cuidais cuidam cuidamos cuidando cuidaram cuidas cuidaste
        cuidastes cuidava cuidavam cuidavamos cuidavas cuidaveis cuidei cuido cuidou cumpre cumprem cumpres cumpri
        cumpria cumpriam cumpriamos cumprias cumprida cumpridas cumprido cumpridos cumprieis cumprimos cumprindo
        cumpriram cumpris cumpriste cumpristes cumpriu cumpro deixa deixada deixadas deixado deixados deixais deixam
        deixamos deixando deixaram deixas deixaste deixastes deixava deixavam deixavamos deixavas deixaveis deixei
        deixo deixou desenvolve desenvolveis desenvolvem desenvolvemos desenvolvendo desenvolveram desenvolves
        desenvolveste desenvolvestes desenvolveu desenvolvi desenvolvia desenvolviam desenvolviamos desenvolvias
        desenvolvida desenvolvidas desenvolvido desenvolvidos desenvolvieis desenvolvo dirige dirigem diriges dirigi
        dirigia dirigiam dirigiamos dirigias dirigida dirigidas dirigido dirigidos dirigieis dirigimos dirigindo
        dirigiram dirigis dirigiste dirigistes dirigiu dirigo encarregada encarregado encarreguei ensina ensinada
        ensinadas ensinado ensinados ensinais ensinam ensinamos ensinando ensinaram ensinas ensinaste ensinastes
        ensinava ensinavam ensinavamos ensinavas ensinaveis ensinei ensino ensinou estuda estudada estudadas estudado
        estudados estudais estudam estudamos estudando estudaram estudas estudaste estudastes estudava estudavam
        estudavamos estudavas estudaveis estudei estudo estudou fala falada faladas falado falados falais falam
        falamos falando falaram falas falaste falastes falava falavam falavamos falavas falaveis falei falo falou fica
        ficado ficando fico ficou fiquei forma formada formadas formado formados formais formam formamos formando
        formaram formas formaste formastes formava formavam formavamos formavas formaveis formei formo formou funda
        fundada fundadas fundado fundados fundais fundam fundamos fundando fundaram fundas fundaste fundastes fundava
        fundavam fundavamos fundavas fundaveis fundei fundo fundou gerencia gerenciada gerenciadas gerenciado
        gerenciados gerenciais gerenciam gerenciamos gerenciando gerenciaram gerencias gerenciaste gerenciastes
        gerenciava gerenciavam gerenciavamos gerenciavas gerenciaveis gerenciei gerencio gerenciou gradua graduada
        graduadas graduado graduados graduais graduam graduamos graduando graduaram graduas graduaste graduastes
        graduava graduavam graduavamos graduavas graduaveis graduei graduo graduou implementa implementada
        implementadas implementado implementados implementais implementam implementamos implementando implementaram
        implementas implementaste implementastes implementava implementavam implementavamos implementavas
        implementaveis implementei implemento implementou inicia iniciada iniciadas iniciado iniciados iniciais
        iniciam iniciamos iniciando iniciaram inicias iniciaste iniciastes iniciava iniciavam iniciavamos iniciavas
        iniciaveis iniciei inicio iniciou introduzi introduzido introduzindo introduziu lanca lancada lancadas lancado
        lancados lancais lancam lancamos lancando lancaram lancas lancaste lancastes lancava lancavam lancavamos
        lancavas lancaveis lancei lanco lancou leciona lecionada lecionadas lecionado lecionados lecionais lecionam
        lecionamos lecionando lecionaram lecionas lecionaste lecionastes lecionava lecionavam lecionavamos lecionavas
        lecionaveis lecionei leciono lecionou lidera liderada lideradas liderado liderados liderais lideram lideramos
        liderando lideraram lideras lideraste liderastes liderava lideravam lideravamos lideravas lideraveis liderei
        lidero liderou mantem mantendo mantenho manteve mantido mantive melhora melhorada melhoradas melhorado
        melhorados melhorais melhoram melhoramos melhorando melhoraram melhoras melhoraste melhorastes melhorava
        melhoravam melhoravamos melhoravas melhoraveis melhorei melhoro melhorou mostra mostrada mostradas mostrado
        mostrados mostrais mostram mostramos mostrando mostraram mostras mostraste mostrastes mostrava mostravam
        mostravamos mostravas mostraveis mostrei mostro mostrou muda mudada mudadas mudado mudados mudais mudam
        mudamos mudando mudaram mudas mudaste mudastes mudava mudavam mudavamos mudavas mudaveis mudei mudo mudou
        obtem obtendo obtenho obteve obtido obtive opera operada operadas operado operados operais operam operamos
        operando operaram operas operaste operastes operava operavam operavamos operavas operaveis operei opero operou
        organiza organizada organizadas organizado organizados organizais organizam organizamos organizando
        organizaram organizas organizaste organizastes organizava organizavam organizavamos organizavas organizaveis
        organizei organizo organizou orienta orientada orientadas orientado orientados orientais orientam orientamos
        orientando orientaram orientas orientaste orientastes orientava orientavam orientavamos orientavas orientaveis
        orientei oriento orientou parte partem partes parti partia partiam partiamos partias participa participada
        participadas participado participados participais participam participamos participando participaram participas
        participaste participastes participava participavam participavamos participavas participaveis participei
        participo participou partida partidas partido partidos partieis partimos partindo partiram partis partiste
        partistes partiu parto permaneceu permaneci permanecido planeja planejada planejadas planejado planejados
        planejais planejam planejamos planejando planejaram planejas planejaste planejastes planejava planejavam
        planejavamos planejavas planejaveis planejei planejo planejou prepara preparada preparadas preparado
        preparados preparais preparam preparamos preparando prepararam preparas preparaste preparastes preparava
        preparavam preparavamos preparavas preparaveis preparei preparo preparou projeta projetada projetadas
        projetado projetados projetais projetam projetamos projetando projetaram projetas projetaste projetastes
        projetava projetavam projetavamos projetavas projetaveis projetei projeto projetou realiza realizada
        realizadas realizado realizados realizais realizam realizamos realizando realizaram realizas realizaste
        realizastes realizava realizavam realizavamos realizavas realizaveis realizei realizo realizou recebe recebeis
        recebem recebemos recebendo receberam recebes recebeste recebestes recebeu recebi recebia recebiam recebiamos
        recebias recebida recebidas recebido recebidos recebieis recebo reduz reduzi reduzido reduzindo reduziu reduzo
        responde respondeis respondem respondemos respondendo responderam respondes respondeste respondestes respondeu
        respondi respondia respondiam respondiamos respondias respondida respondidas respondido respondidos
        respondieis respondo responsavel serve servem serves servi servia serviam serviamos servias servida servidas
        servido servidos servieis servimos servindo serviram servis serviste servistes serviu servo supervisiona
        supervisionada supervisionadas supervisionado supervisionados supervisionais supervisionam supervisionamos
        supervisionando supervisionaram supervisionas supervisionaste supervisionastes supervisionava supervisionavam
        supervisionavamos supervisionavas supervisionaveis supervisionei supervisiono supervisionou termina terminada
        terminadas terminado terminados terminais terminam terminamos terminando terminaram terminas terminaste
        terminastes terminava terminavam terminavamos terminavas terminaveis terminei termino terminou torna tornado
        tornando tornei torno tornou trabalha trabalhada trabalhadas trabalhado trabalhados trabalhais trabalham
        trabalhamos trabalhando trabalharam trabalhas trabalhaste trabalhastes trabalhava trabalhavam trabalhavamos
        trabalhavas trabalhaveis trabalhei trabalho trabalhou usa usada usadas usado usados usais usam usamos usando
        usar usaram usas usaste usastes usava usavam usavamos usavas usaveis usei uso usou vende vendeis vendem
        vendemos vendendo venderam vendes vendeste vendestes vendeu vendi vendia vendiam vendiamos vendias vendida
        vendidas vendido vendidos vendieis vendo verifica verificada verificadas verificado verificados verificais
        verificam verificamos verificando verificaram verificas verificaste verificastes verificava verificavam
        verificavamos verificavas verificaveis verificei verifico verificou vive viveis vivem vivemos vivendo viveram
        vives viveste vivestes viveu vivi vivia viviam viviamos vivias vivida vividas vivido vividos vivieis vivo
        """,
        /// The infinitives of the verbs of a CV: no present or past, so they explain nothing and say nothing done.
        infinitives: """
        acompanhar administrar ajudar analisar aprender apresentar assistir atender atuar colaborar comecar completar
        concluir contratar controlar coordenar cozinhar criar cuidar cumprir deixar desenvolver dirigir ensinar
        estudar falar ficar formar fundar gerenciar graduar implementar iniciar introduzir lancar lecionar liderar
        manter melhorar mostrar mudar obter operar organizar orientar participar partir planejar preparar projetar
        realizar receber reduzir responder servir supervisionar terminar tornar trabalhar vender verificar viver
        """,
        /// Words of time, period and unit, and the months.
        time: """
        abril agora agosto ano anos anterior antiga antigo atual atualmente decada dezembro dia dias fevereiro hoje
        hora horas integral inverno janeiro julho junho maio marco mes meses novembro outono outubro parcial passado
        presente primavera semana semanas setembro temporada verao
        """,
        /// Words of level, and the CEFR codes.
        level: """
        a1 a2 avancada avancado b1 b2 basica basico bilingue c1 c2 elementar especialista experto fluente iniciante
        intermediaria intermediario lingua materna nativa nativo nivel
        """,
        /// Words of studying and graduating.
        studying: """
        academia colegio curso cursos diploma doutorado escola escolas estudante estudantes estudos exame faculdade
        fundamental graduacao instituto licenciatura mestrado primaria secundaria tese universidade universidades
        """,
        /// Prepositions and adverbs of time, and the conjunctions that join them: what a pure time phrase is made of, with years.
        timePhrase: """
        a agora antes ate atualmente de depois desde durante e em entre ou partir
        """,
        /// Words of graduating: a time phrase that holds one joins an education entry and gives its end date.
        graduating: """
        completei conclui concluida concluido finalizei formada formadas formado formados formei formou graduei graduou
        terminada terminado terminei
        """,
        /// Words that go with them in a graduation phrase.
        graduationFrame: """
        me
        """,
        /// The present and past of to be, as written with accents: a verb that says something done on its own.
        beForms: """
        era eram eramos eras estamos estao estava estavam esteve estive estiveram estou está estão foi fomos foram
        foste fui sao somos sou são é éramos és
        """,
        /// The auxiliaries of the perfect, as written with accents: a verb that says something done when a listed form follows it.
        auxiliaries: """
        tem temos tenho tens teve tido tinha tinham tinhamos tinhas tive tiveram têm tínhamos
        """,
        /// The forms of a verb that say another person than I, as written with accents, in the languages that drop the pronoun.
        otherPersons: """
        acompanha acompanhais acompanham acompanhamos acompanharam acompanhas acompanhaste acompanhastes acompanhavam
        acompanhavamos acompanhavas acompanhaveis acompanhou acompanhávamos acompanháveis administra administrais
        administram administramos administraram administras administraste administrastes administravam administravamos
        administravas administraveis administrou administrávamos administráveis ajuda ajudais ajudam ajudamos ajudaram
        ajudas ajudaste ajudastes ajudavam ajudavamos ajudavas ajudaveis ajudou ajudávamos ajudáveis analisa analisais
        analisam analisamos analisaram analisas analisaste analisastes analisavam analisavamos analisavas analisaveis
        analisou analisávamos analisáveis aprende aprendeis aprendem aprendemos aprenderam aprendes aprendeste
        aprendestes aprendeu aprendiam aprendiamos aprendias aprendieis aprendíamos aprendíeis apresenta apresentais
        apresentam apresentamos apresentaram apresentas apresentaste apresentastes apresentavam apresentavamos
        apresentavas apresentaveis apresentou apresentávamos apresentáveis assiste assistem assistes assistiam
        assistiamos assistias assistieis assistimos assistiram assistis assististe assististes assistiu assistíamos
        assistíeis atende atendeis atendem atendemos atenderam atendes atendeste atendestes atendeu atendiam
        atendiamos atendias atendieis atendíamos atendíeis atua atuais atuam atuamos atuaram atuas atuaste atuastes
        atuavam atuavamos atuavas atuaveis atuou atuávamos atuáveis colabora colaborais colaboram colaboramos
        colaboraram colaboras colaboraste colaborastes colaboravam colaboravamos colaboravas colaboraveis colaborou
        colaborávamos colaboráveis comeca comecais comecam comecamos comecaram comecas comecaste comecastes comecavam
        comecavamos comecavas comecaveis comecou comecávamos comecáveis completa completais completam completamos
        completaram completas completaste completastes completavam completavamos completavas completaveis completou
        completávamos completáveis concluiu contrata contratais contratam contratamos contrataram contratas
        contrataste contratastes contratavam contratavamos contratavas contrataveis contratou contratávamos
        contratáveis controla controlais controlam controlamos controlaram controlas controlaste controlastes
        controlavam controlavamos controlavas controlaveis controlou controlávamos controláveis coordena coordenais
        coordenam coordenamos coordenaram coordenas coordenaste coordenastes coordenavam coordenavamos coordenavas
        coordenaveis coordenou coordenávamos coordenáveis cozinha cozinhais cozinham cozinhamos cozinharam cozinhas
        cozinhaste cozinhastes cozinhavam cozinhavamos cozinhavas cozinhaveis cozinhou cozinhávamos cozinháveis cria
        criais criam criamos criaram crias criaste criastes criavam criavamos criavas criaveis criou criávamos
        criáveis cuida cuidais cuidam cuidamos cuidaram cuidas cuidaste cuidastes cuidavam cuidavamos cuidavas
        cuidaveis cuidou cuidávamos cuidáveis cumpre cumprem cumpres cumpriam cumpriamos cumprias cumprieis cumprimos
        cumpriram cumpris cumpriste cumpristes cumpriu cumpríamos cumpríeis deixa deixais deixam deixamos deixaram
        deixas deixaste deixastes deixavam deixavamos deixavas deixaveis deixou deixávamos deixáveis desenvolve
        desenvolveis desenvolvem desenvolvemos desenvolveram desenvolves desenvolveste desenvolvestes desenvolveu
        desenvolviam desenvolviamos desenvolvias desenvolvieis desenvolvíamos desenvolvíeis dirige dirigem diriges
        dirigiam dirigiamos dirigias dirigieis dirigimos dirigiram dirigis dirigiste dirigistes dirigiu dirigíamos
        dirigíeis ensina ensinais ensinam ensinamos ensinaram ensinas ensinaste ensinastes ensinavam ensinavamos
        ensinavas ensinaveis ensinou ensinávamos ensináveis eram eramos eras esta estamos estao estavam esteve
        estiveram estuda estudais estudam estudamos estudaram estudas estudaste estudastes estudavam estudavamos
        estudavas estudaveis estudou estudávamos estudáveis está estão fala falais falam falamos falaram falas falaste
        falastes falavam falavamos falavas falaveis falou falávamos faláveis fica ficou foi fomos foram forma formais
        formam formamos formaram formas formaste formastes formavam formavamos formavas formaveis formou formávamos
        formáveis foste funda fundais fundam fundamos fundaram fundas fundaste fundastes fundavam fundavamos fundavas
        fundaveis fundou fundávamos fundáveis gerencia gerenciais gerenciam gerenciamos gerenciaram gerencias
        gerenciaste gerenciastes gerenciavam gerenciavamos gerenciavas gerenciaveis gerenciou gerenciávamos
        gerenciáveis gradua graduais graduam graduamos graduaram graduas graduaste graduastes graduavam graduavamos
        graduavas graduaveis graduou graduávamos graduáveis implementa implementais implementam implementamos
        implementaram implementas implementaste implementastes implementavam implementavamos implementavas
        implementaveis implementou implementávamos implementáveis inicia iniciais iniciam iniciamos iniciaram inicias
        iniciaste iniciastes iniciavam iniciavamos iniciavas iniciaveis iniciou iniciávamos iniciáveis introduziu
        lanca lancais lancam lancamos lancaram lancas lancaste lancastes lancavam lancavamos lancavas lancaveis lancou
        lancávamos lancáveis leciona lecionais lecionam lecionamos lecionaram lecionas lecionaste lecionastes
        lecionavam lecionavamos lecionavas lecionaveis lecionou lecionávamos lecionáveis lidera liderais lideram
        lideramos lideraram lideras lideraste liderastes lideravam lideravamos lideravas lideraveis liderou
        liderávamos lideráveis mantem manteve mantém melhora melhorais melhoram melhoramos melhoraram melhoras
        melhoraste melhorastes melhoravam melhoravamos melhoravas melhoraveis melhorou melhorávamos melhoráveis mostra
        mostrais mostram mostramos mostraram mostras mostraste mostrastes mostravam mostravamos mostravas mostraveis
        mostrou mostrávamos mostráveis muda mudais mudam mudamos mudaram mudas mudaste mudastes mudavam mudavamos
        mudavas mudaveis mudou mudávamos mudáveis obtem obteve obtém opera operais operam operamos operaram operas
        operaste operastes operavam operavamos operavas operaveis operou operávamos operáveis organiza organizais
        organizam organizamos organizaram organizas organizaste organizastes organizavam organizavamos organizavas
        organizaveis organizou organizávamos organizáveis orienta orientais orientam orientamos orientaram orientas
        orientaste orientastes orientavam orientavamos orientavas orientaveis orientou orientávamos orientáveis parte
        partem partes partiam partiamos partias participa participais participam participamos participaram participas
        participaste participastes participavam participavamos participavas participaveis participou participávamos
        participáveis partieis partimos partiram partis partiste partistes partiu partíamos partíeis permaneceu
        planeja planejais planejam planejamos planejaram planejas planejaste planejastes planejavam planejavamos
        planejavas planejaveis planejou planejávamos planejáveis prepara preparais preparam preparamos prepararam
        preparas preparaste preparastes preparavam preparavamos preparavas preparaveis preparou preparávamos
        preparáveis projeta projetais projetam projetamos projetaram projetas projetaste projetastes projetavam
        projetavamos projetavas projetaveis projetou projetávamos projetáveis realiza realizais realizam realizamos
        realizaram realizas realizaste realizastes realizavam realizavamos realizavas realizaveis realizou
        realizávamos realizáveis recebe recebeis recebem recebemos receberam recebes recebeste recebestes recebeu
        recebiam recebiamos recebias recebieis recebíamos recebíeis reduz reduziu responde respondeis respondem
        respondemos responderam respondes respondeste respondestes respondeu respondiam respondiamos respondias
        respondieis respondíamos respondíeis sao serve servem serves serviam serviamos servias servieis servimos
        serviram servis serviste servistes serviu servíamos servíeis somos supervisiona supervisionais supervisionam
        supervisionamos supervisionaram supervisionas supervisionaste supervisionastes supervisionavam
        supervisionavamos supervisionavas supervisionaveis supervisionou supervisionávamos supervisionáveis são tem
        temos tens termina terminais terminam terminamos terminaram terminas terminaste terminastes terminavam
        terminavamos terminavas terminaveis terminou terminávamos termináveis teve tinham tinhamos tinhas tiveram
        torna tornou trabalha trabalhais trabalham trabalhamos trabalharam trabalhas trabalhaste trabalhastes
        trabalhavam trabalhavamos trabalhavas trabalhaveis trabalhou trabalhávamos trabalháveis têm tínhamos usa usais
        usam usamos usaram usas usaste usastes usavam usavamos usavas usaveis usou usávamos usáveis vende vendeis
        vendem vendemos venderam vendes vendeste vendestes vendeu vendiam vendiamos vendias vendieis vendíamos
        vendíeis verifica verificais verificam verificamos verificaram verificas verificaste verificastes verificavam
        verificavamos verificavas verificaveis verificou verificávamos verificáveis vive viveis vivem vivemos viveram
        vives viveste vivestes viveu viviam viviamos vivias vivieis vivíamos vivíeis é éramos és
        """,
        /// The forms of a verb that a noun can be the subject of, as written with accents, in the languages that drop the pronoun.
        thirdPersons: """
        acompanha acompanham acompanharam acompanhava acompanhavam acompanhou administra administram administraram
        administrava administravam administrou ajuda ajudam ajudaram ajudava ajudavam ajudou analisa analisam
        analisaram analisava analisavam analisou aprende aprendem aprenderam aprendeu aprendia aprendiam apresenta
        apresentam apresentaram apresentava apresentavam apresentou assiste assistem assistia assistiam assistiram
        assistiu atende atendem atenderam atendeu atendia atendiam atua atuam atuaram atuava atuavam atuou colabora
        colaboram colaboraram colaborava colaboravam colaborou comeca comecam comecaram comecava comecavam comecou
        completa completam completaram completava completavam completou concluiu contrata contratam contrataram
        contratava contratavam contratou controla controlam controlaram controlava controlavam controlou coordena
        coordenam coordenaram coordenava coordenavam coordenou cozinha cozinham cozinharam cozinhava cozinhavam
        cozinhou cria criam criaram criava criavam criou cuida cuidam cuidaram cuidava cuidavam cuidou cumpre cumprem
        cumpria cumpriam cumpriram cumpriu deixa deixam deixaram deixava deixavam deixou desenvolve desenvolvem
        desenvolveram desenvolveu desenvolvia desenvolviam dirige dirigem dirigia dirigiam dirigiram dirigiu ensina
        ensinam ensinaram ensinava ensinavam ensinou era eram estava estavam esteve estiveram estuda estudam estudaram
        estudava estudavam estudou está estão fala falam falaram falava falavam falou fica ficou foi foram forma
        formam formaram formava formavam formou funda fundam fundaram fundava fundavam fundou gerencia gerenciam
        gerenciaram gerenciava gerenciavam gerenciou gradua graduam graduaram graduava graduavam graduou implementa
        implementam implementaram implementava implementavam implementou inicia iniciam iniciaram iniciava iniciavam
        iniciou introduziu lanca lancam lancaram lancava lancavam lancou leciona lecionam lecionaram lecionava
        lecionavam lecionou lidera lideram lideraram liderava lideravam liderou manteve mantém melhora melhoram
        melhoraram melhorava melhoravam melhorou mostra mostram mostraram mostrava mostravam mostrou muda mudam
        mudaram mudava mudavam mudou obteve obtém opera operam operaram operava operavam operou organiza organizam
        organizaram organizava organizavam organizou orienta orientam orientaram orientava orientavam orientou parte
        partem partia partiam participa participam participaram participava participavam participou partiram partiu
        permaneceu planeja planejam planejaram planejava planejavam planejou prepara preparam prepararam preparava
        preparavam preparou projeta projetam projetaram projetava projetavam projetou realiza realizam realizaram
        realizava realizavam realizou recebe recebem receberam recebeu recebia recebiam reduz reduziu responde
        respondem responderam respondeu respondia respondiam serve servem servia serviam serviram serviu supervisiona
        supervisionam supervisionaram supervisionava supervisionavam supervisionou são tem termina terminam terminaram
        terminava terminavam terminou teve tinha tinham tiveram torna tornou trabalha trabalham trabalharam trabalhava
        trabalhavam trabalhou têm usa usam usaram usava usavam usou vende vendem venderam vendeu vendia vendiam
        verifica verificam verificaram verificava verificavam verificou vive vivem viveram viveu vivia viviam é
        """,
        /// Everyday verbs in the third person, as written with accents: no CV verbs, but the ones a noun before them is the subject of.
        everydayVerbs: """
        adora adoram adoraram adorava adoravam adorou ama amam amaram amava amavam amou aprecia apreciam apreciaram
        apreciava apreciavam apreciou bebe bebem beberam bebeu bebia bebiam caminha caminham caminharam caminhava
        caminhavam caminhou canta cantam cantaram cantava cantavam cantou coleciona colecionam colecionaram
        colecionava colecionavam colecionou compra compram compraram comprava compravam comprou conhece conhecem
        conheceram conheceu conhecia conheciam corre correm correram correu corria corriam cre crem creram creu cria
        criam curta curtam curtaram curtava curtavam curtou dança dançam dançaram dançava dançavam dançou disse
        disseram diz dizem dizia diziam domina dominam dominaram dominava dominavam dominou escuta escutam escutaram
        escutava escutavam escutou fala falam falaram falava falavam falou faz fazem fazia faziam fez fica ficam
        ficaram ficava ficavam ficou fizeram foi foram gosta gostam gostaram gostava gostavam gostou ia iam joga jogam
        jogaram jogava jogavam jogou leem leram leu lia liam lê mora moram moraram morava moravam morou pedala pedalam
        pedalaram pedalava pedalavam pedalou pinta pintam pintaram pintava pintavam pintou pode podem podia podiam
        pratica praticam praticaram praticava praticavam praticou prefere preferem preferia preferiam preferiram
        preferiu puderam pôde reside residem resideram resideu residia residiam residiram residiu sabe sabem sabia
        sabiam saem sai saiu saía saíam saíram sonha sonham sonharam sonhava sonhavam sonhou soube souberam tem teve
        tinha tinham tiveram têm usa usam usaram usava usavam usou vai veem veio vem via viaja viajam viajaram viajava
        viajavam viajou viam vieram vinha vinham viram viu vive vivem vivia viviam viviram viviu vão vê vêm
        """,
        /// Words of negation, doubt or degree, wish or intention, future and condition: in no other list.
        modality: """
        seria serias seriamos seriam faria farias fariamos fariam teria terias teriamos teriam adoraria adorarias adorariamos
        adorariam quereria quererias quereriamos quereriam
        sonho_em sonho_com intencao_de
        acompanhara acompanharao acompanharas acompanharei acompanhareis acompanharemos acompanharia acompanhariam
        acompanhariamos acompanharias acompanharieis administrara administrarao administraras administrarei
        administrareis administraremos administraria administrariam administrariamos administrarias administrarieis
        ajudara ajudarao ajudaras ajudarei ajudareis ajudaremos ajudaria ajudariam ajudariamos ajudarias ajudarieis
        analisara analisarao analisaras analisarei analisareis analisaremos analisaria analisariam analisariamos
        analisarias analisarieis apenas aprendera aprenderao aprenderas aprenderei aprendereis aprenderemos aprenderia
        aprenderiam aprenderiamos aprenderias aprenderieis apresentara apresentarao apresentaras apresentarei
        apresentareis apresentaremos apresentaria apresentariam apresentariamos apresentarias apresentarieis assistira
        assistirao assistiras assistirei assistireis assistiremos assistiria assistiriam assistiriamos assistirias
        assistirieis atendera atenderao atenderas atenderei atendereis atenderemos atenderia atenderiam atenderiamos
        atenderias atenderieis atuara atuarao atuaras atuarei atuareis atuaremos atuaria atuariam atuariamos atuarias
        atuarieis caso colaborara colaborarao colaboraras colaborarei colaborareis colaboraremos colaboraria
        colaborariam colaborariamos colaborarias colaborarieis comecara comecarao comecaras comecarei comecareis
        comecaremos comecaria comecariam comecariamos comecarias comecarieis completara completarao completaras
        completarei completareis completaremos completaria completariam completariamos completarias completarieis
        contratara contratarao contrataras contratarei contratareis contrataremos contrataria contratariam
        contratariamos contratarias contratarieis controlara controlarao controlaras controlarei controlareis
        controlaremos controlaria controlariam controlariamos controlarias controlarieis coordenara coordenarao
        coordenaras coordenarei coordenareis coordenaremos coordenaria coordenariam coordenariamos coordenarias
        coordenarieis cozinhara cozinharao cozinharas cozinharei cozinhareis cozinharemos cozinharia cozinhariam
        cozinhariamos cozinharias cozinharieis criara criarao criaras criarei criareis criaremos criaria criariam
        criariamos criarias criarieis cuidara cuidarao cuidaras cuidarei cuidareis cuidaremos cuidaria cuidariam
        cuidariamos cuidarias cuidarieis cumprira cumprirao cumpriras cumprirei cumprireis cumpriremos cumpriria
        cumpririam cumpririamos cumpririas cumpririeis deixara deixarao deixaras deixarei deixareis deixaremos
        deixaria deixariam deixariamos deixarias deixarieis desejo desenvolvera desenvolverao desenvolveras
        desenvolverei desenvolvereis desenvolveremos desenvolveria desenvolveriam desenvolveriamos desenvolverias
        desenvolverieis deve deveria devo dirigira dirigirao dirigiras dirigirei dirigireis dirigiremos dirigiria
        dirigiriam dirigiriamos dirigirias dirigirieis ensinara ensinarao ensinaras ensinarei ensinareis ensinaremos
        ensinaria ensinariam ensinariamos ensinarias ensinarieis espera esperas espero estudara estudarao estudaras
        estudarei estudareis estudaremos estudaria estudariam estudariamos estudarias estudarieis falara falarao
        falaras falarei falareis falaremos falaria falariam falariamos falarias falarieis formara formarao formaras
        formarei formareis formaremos formaria formariam formariamos formarias formarieis fundara fundarao fundaras
        fundarei fundareis fundaremos fundaria fundariam fundariamos fundarias fundarieis gerenciara gerenciarao
        gerenciaras gerenciarei gerenciareis gerenciaremos gerenciaria gerenciariam gerenciariamos gerenciarias
        gerenciarieis gostaria graduara graduarao graduaras graduarei graduareis graduaremos graduaria graduariam
        graduariamos graduarias graduarieis hei implementara implementarao implementaras implementarei implementareis
        implementaremos implementaria implementariam implementariamos implementarias implementarieis iniciara
        iniciarao iniciaras iniciarei iniciareis iniciaremos iniciaria iniciariam iniciariamos iniciarias iniciarieis
        jamais lancara lancarao lancaras lancarei lancareis lancaremos lancaria lancariam lancariamos lancarias
        lancarieis lecionara lecionarao lecionaras lecionarei lecionareis lecionaremos lecionaria lecionariam
        lecionariamos lecionarias lecionarieis liderara liderarao lideraras liderarei liderareis lideraremos lideraria
        liderariam liderariamos liderarias liderarieis mal melhorara melhorarao melhoraras melhorarei melhorareis
        melhoraremos melhoraria melhorariam melhorariamos melhorarias melhorarieis mostrara mostrarao mostraras
        mostrarei mostrareis mostraremos mostraria mostrariam mostrariamos mostrarias mostrarieis mudara mudarao
        mudaras mudarei mudareis mudaremos mudaria mudariam mudariamos mudarias mudarieis nada nao nem nenhum nenhuma
        ninguem nunca operara operarao operaras operarei operareis operaremos operaria operariam operariamos operarias
        operarieis organizara organizarao organizaras organizarei organizareis organizaremos organizaria organizariam
        organizariamos organizarias organizarieis orientara orientarao orientaras orientarei orientareis orientaremos
        orientaria orientariam orientariamos orientarias orientarieis parcialmente participara participarao
        participaras participarei participareis participaremos participaria participariam participariamos
        participarias participarieis partira partirao partiras partirei partireis partiremos partiria partiriam
        partiriamos partirias partirieis planeio planejara planejarao planejaras planejarei planejareis planejaremos
        planejaria planejariam planejariamos planejarias planejarieis pode podem podemos poderia possivelmente posso
        preparara prepararao prepararas prepararei preparareis prepararemos prepararia preparariam preparariamos
        prepararias prepararieis pretendo projetara projetarao projetaras projetarei projetareis projetaremos
        projetaria projetariam projetariamos projetarias projetarieis provavelmente quase quer querem queremos queres
        queria quero realizara realizarao realizaras realizarei realizareis realizaremos realizaria realizariam
        realizariamos realizarias realizarieis recebera receberao receberas receberei recebereis receberemos receberia
        receberiam receberiamos receberias receberieis respondera responderao responderas responderei respondereis
        responderemos responderia responderiam responderiamos responderias responderieis se sem sera serao serei
        seremos servira servirao serviras servirei servireis serviremos serviria serviriam serviriamos servirias
        servirieis supervisionara supervisionarao supervisionaras supervisionarei supervisionareis supervisionaremos
        supervisionaria supervisionariam supervisionariamos supervisionarias supervisionarieis talvez tera terei
        terminara terminarao terminaras terminarei terminareis terminaremos terminaria terminariam terminariamos
        terminarias terminarieis trabalhara trabalharao trabalharas trabalharei trabalhareis trabalharemos trabalharia
        trabalhariam trabalhariamos trabalharias trabalharieis usara usarao usaras usarei usareis usaremos usaria
        usariam usariamos usarias usarieis vendera venderao venderas venderei vendereis venderemos venderia venderiam
        venderiamos venderias venderieis verificara verificarao verificaras verificarei verificareis verificaremos
        verificaria verificariam verificariamos verificarias verificarieis vivera viverao viveras viverei vivereis
        viveremos viveria viveriam viveriamos viverias viverieis
        """
    )
}
