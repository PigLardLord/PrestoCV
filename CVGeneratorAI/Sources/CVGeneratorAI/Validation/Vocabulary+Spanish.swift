/// The closed vocabulary of Spanish (ADR 0023), written as `DescriptionText.normalized` writes a word: lower case,
/// without accents, an elided article as a word of its own; but for the forms of to be and the auxiliaries, which keep them.
extension Vocabulary {
    static let spanish = Words(
        /// Articles, prepositions, pronouns, auxiliaries, conjunctions and subordinators.
        function: """
        a ademas ahi al algun alguna algunas algunos alli ante antes aquel aquella aquellas aquello aquellos aqui asi
        aun aunque bajo cada como con contra cual cuales cuando cuya cuyo d de del desde despues donde durante e el en
        entonces entre era erais eramos eran eras eres es esa esas ese eso esos esta estaba estabamos estaban estabas
        estado estais estamos estan estar estas este esto estos estoy estuve estuvieron estuvimos estuviste estuvo fue
        fueron fui fuimos fuiste fuisteis ha habeis haber habia habiamos habian habias habido hace hacemos hacen hacer
        haces hacia haciendo hago han has hasta hay he hecho hemos hice hicieron hicimos hizo hube hubo l la las lo
        los luego m mas me mediante mi mia mientras mio mis misma mismas mismo mismos muy nos nosotras nosotros
        nuestra nuestras nuestro nuestros o os otra otras otro otros para pero por porque pues qu que quien quienes s
        segun ser sido siendo sino sobre sois somos son soy tambien tan te teneis tenemos tengo tenia teniamos tenian
        tenias tenido teniendo ti tiene tienen tienes toda todas todavia todo todos tras tu tus tuve tuvieron tuvimos
        tuviste tuvo u un una unas unos varias varios vosotros vuestro y ya yo
        """,
        /// Verbs of a CV: their inflected forms, the infinitives set apart.
        verbs: """
        administra administraba administrabais administrabamos administraban administrabas administrada administradas
        administrado administrados administrais administramos administran administrando administraron administras
        administraste administrasteis administre administro analiza analizaba analizabais analizabamos analizaban
        analizabas analizada analizadas analizado analizados analizais analizamos analizan analizando analizaron
        analizas analizaste analizasteis analize analizo aprende aprendeis aprendemos aprenden aprendes aprendi
        aprendia aprendiais aprendiamos aprendian aprendias aprendida aprendidas aprendido aprendidos aprendiendo
        aprendieron aprendimos aprendio aprendiste aprendisteis aprendo asista asistaba asistabais asistabamos
        asistaban asistabas asistada asistadas asistado asistados asistais asistamos asistan asistando asistaron
        asistas asistaste asistasteis asiste asisto atende atendeis atendemos atenden atendes atendi atendia atendiais
        atendiamos atendian atendias atendida atendidas atendido atendidos atendiendo atendieron atendimos atendio
        atendiste atendisteis atendo ayuda ayudaba ayudabais ayudabamos ayudaban ayudabas ayudada ayudadas ayudado
        ayudados ayudais ayudamos ayudan ayudando ayudaron ayudas ayudaste ayudasteis ayude ayudo cocina cocinaba
        cocinabais cocinabamos cocinaban cocinabas cocinada cocinadas cocinado cocinados cocinais cocinamos cocinan
        cocinando cocinaron cocinas cocinaste cocinasteis cocine cocino colabora colaboraba colaborabais colaborabamos
        colaboraban colaborabas colaborada colaboradas colaborado colaborados colaborais colaboramos colaboran
        colaborando colaboraron colaboras colaboraste colaborasteis colabore colaboro comence comenzado comenzando
        comenzo comienza comienzo completa completaba completabais completabamos completaban completabas completada
        completadas completado completados completais completamos completan completando completaron completas
        completaste completasteis complete completo contrata contrataba contratabais contratabamos contrataban
        contratabas contratada contratadas contratado contratados contratais contratamos contratan contratando
        contrataron contratas contrataste contratasteis contrate contrato controla controlaba controlabais
        controlabamos controlaban controlabas controlada controladas controlado controlados controlais controlamos
        controlan controlando controlaron controlas controlaste controlasteis controle controlo converti convertida
        convertido convertirme convirtio coordina coordinaba coordinabais coordinabamos coordinaban coordinabas
        coordinada coordinadas coordinado coordinados coordinais coordinamos coordinan coordinando coordinaron
        coordinas coordinaste coordinasteis coordine coordino crea creaba creabais creabamos creaban creabas creada
        creadas creado creados creais creamos crean creando crearon creas creaste creasteis cree creo cuida cuidaba
        cuidabais cuidabamos cuidaban cuidabas cuidada cuidadas cuidado cuidados cuidais cuidamos cuidan cuidando
        cuidaron cuidas cuidaste cuidasteis cuide cuido cumple cumplen cumples cumpli cumplia cumpliais cumpliamos
        cumplian cumplias cumplida cumplidas cumplido cumplidos cumpliendo cumplieron cumplimos cumplio cumplis
        cumpliste cumplisteis cumplo da dado dar deja dejaba dejabais dejabamos dejaban dejabas dejada dejadas dejado
        dejados dejais dejamos dejan dejando dejaron dejas dejaste dejasteis deje dejo desarrolla desarrollaba
        desarrollabais desarrollabamos desarrollaban desarrollabas desarrollada desarrolladas desarrollado
        desarrollados desarrollais desarrollamos desarrollan desarrollando desarrollaron desarrollas desarrollaste
        desarrollasteis desarrolle desarrollo di dio dirige dirigen diriges dirigi dirigia dirigida dirigido
        dirigiendo dirigieron dirigimos dirigio dirijo disena disenaba disenabais disenabamos disenaban disenabas
        disenada disenadas disenado disenados disenais disenamos disenan disenando disenaron disenas disenaste
        disenasteis disene diseno doy encarga encargaba encargabais encargabamos encargaban encargabas encargada
        encargadas encargado encargados encargais encargamos encargan encargando encargaron encargas encargaste
        encargasteis encarge encargo ensena ensenaba ensenabais ensenabamos ensenaban ensenabas ensenada ensenadas
        ensenado ensenados ensenais ensenamos ensenan ensenando ensenaron ensenas ensenaste ensenasteis ensene enseno
        escribe escriben escribes escribi escribia escribiais escribiamos escribian escribias escribida escribidas
        escribido escribidos escribiendo escribieron escribimos escribio escribis escribiste escribisteis escribo
        estudia estudiaba estudiabais estudiabamos estudiaban estudiabas estudiada estudiadas estudiado estudiados
        estudiais estudiamos estudian estudiando estudiaron estudias estudiaste estudiasteis estudie estudio forma
        formaba formabais formabamos formaban formabas formada formadas formado formados formais formamos forman
        formando formaron formas formaste formasteis forme formo funda fundaba fundabais fundabamos fundaban fundabas
        fundada fundadas fundado fundados fundais fundamos fundan fundando fundaron fundas fundaste fundasteis funde
        fundo gestiona gestionaba gestionabais gestionabamos gestionaban gestionabas gestionada gestionadas gestionado
        gestionados gestionais gestionamos gestionan gestionando gestionaron gestionas gestionaste gestionasteis
        gestione gestiono gradua graduada graduado gradue graduo habla hablaba hablabais hablabamos hablaban hablabas
        hablada habladas hablado hablados hablais hablamos hablan hablando hablaron hablas hablaste hablasteis hable
        hablo imparta impartaba impartabais impartabamos impartaban impartabas impartada impartadas impartado
        impartados impartais impartamos impartan impartando impartaron impartas impartaste impartasteis imparte
        imparto implementa implementaba implementabais implementabamos implementaban implementabas implementada
        implementadas implementado implementados implementais implementamos implementan implementando implementaron
        implementas implementaste implementasteis implemente implemento incorporado incorpore incorporo inicia
        iniciaba iniciabais iniciabamos iniciaban iniciabas iniciada iniciadas iniciado iniciados iniciais iniciamos
        inician iniciando iniciaron inicias iniciaste iniciasteis inicie inicio introduce introducido introdujo
        introduzco lanza lanzaba lanzabais lanzabamos lanzaban lanzabas lanzada lanzadas lanzado lanzados lanzais
        lanzamos lanzan lanzando lanzaron lanzas lanzaste lanzasteis lanze lanzo licenciada licenciado licenciarme
        licencie lidera lideraba liderabais liderabamos lideraban liderabas liderada lideradas liderado liderados
        liderais lideramos lideran liderando lideraron lideras lideraste liderasteis lidere lidero mantengo mantenido
        mantiene mantuve mantuvo mejora mejoraba mejorabais mejorabamos mejoraban mejorabas mejorada mejoradas
        mejorado mejorados mejorais mejoramos mejoran mejorando mejoraron mejoras mejoraste mejorasteis mejore mejoro
        mostra mostraba mostrabais mostrabamos mostraban mostrabas mostrada mostradas mostrado mostrados mostrais
        mostramos mostran mostrando mostraron mostras mostraste mostrasteis mostre mostro obtengo obtenido obteniendo
        obtiene obtuve obtuvo ocupada ocupado ocupe ocupo ofrece ofreceis ofrecemos ofrecen ofreces ofreci ofrecia
        ofreciais ofreciamos ofrecian ofrecias ofrecida ofrecidas ofrecido ofrecidos ofreciendo ofrecieron ofrecimos
        ofrecio ofreciste ofrecisteis ofreco opera operaba operabais operabamos operaban operabas operada operadas
        operado operados operais operamos operan operando operaron operas operaste operasteis opere opero organiza
        organizaba organizabais organizabamos organizaban organizabas organizada organizadas organizado organizados
        organizais organizamos organizan organizando organizaron organizas organizaste organizasteis organize organizo
        participa participaba participabais participabamos participaban participabas participada participadas
        participado participados participais participamos participan participando participaron participas participaste
        participasteis participe participo permanece permaneci permanecido permanecio permanezco permite permiten
        permites permiti permitia permitiais permitiamos permitian permitias permitida permitidas permitido permitidos
        permitiendo permitieron permitimos permitio permitis permitiste permitisteis permito planifica planificaba
        planificabais planificabamos planificaban planificabas planificada planificadas planificado planificados
        planificais planificamos planifican planificando planificaron planificas planificaste planificasteis planifice
        planifico pone pongo prepara preparaba preparabais preparabamos preparaban preparabas preparada preparadas
        preparado preparados preparais preparamos preparan preparando prepararon preparas preparaste preparasteis
        prepare preparo puesto puse puso realiza realizaba realizabais realizabamos realizaban realizabas realizada
        realizadas realizado realizados realizais realizamos realizan realizando realizaron realizas realizaste
        realizasteis realize realizo recibe recibeis recibemos reciben recibes recibi recibia recibiais recibiamos
        recibian recibias recibida recibidas recibido recibidos recibiendo recibieron recibimos recibio recibiste
        recibisteis recibo reduce reducido reduciendo redujo reduzco responde respondeis respondemos responden
        respondes respondi respondia respondiais respondiamos respondian respondias respondida respondidas respondido
        respondidos respondiendo respondieron respondimos respondio respondiste respondisteis respondo sale salgo sali
        salido salio supervisa supervisaba supervisabais supervisabamos supervisaban supervisabas supervisada
        supervisadas supervisado supervisados supervisais supervisamos supervisan supervisando supervisaron supervisas
        supervisaste supervisasteis supervise superviso termina terminaba terminabais terminabamos terminaban
        terminabas terminada terminadas terminado terminados terminais terminamos terminan terminando terminaron
        terminas terminaste terminasteis termine termino titulada titulado titularme trabaja trabajaba trabajabais
        trabajabamos trabajaban trabajabas trabajada trabajadas trabajado trabajados trabajais trabajamos trabajan
        trabajando trabajaron trabajas trabajaste trabajasteis trabaje trabajo trasladado traslade usa usaba usabais
        usabamos usaban usabas usada usadas usado usados usais usamos usan usando usar usaron usas usaste usasteis use
        uso vende vendeis vendemos venden vendes vendi vendia vendiais vendiamos vendian vendias vendida vendidas
        vendido vendidos vendiendo vendieron vendimos vendio vendiste vendisteis vendo vengo venido verifica
        verificaba verificabais verificabamos verificaban verificabas verificada verificadas verificado verificados
        verificais verificamos verifican verificando verificaron verificas verificaste verificasteis verifice verifico
        viene vine vino vive viveis vivemos viven vives vivi vivia viviais viviamos vivian vivias vivida vividas
        vivido vividos viviendo vivieron vivimos vivio viviste vivisteis vivo
        """,
        /// The infinitives of the verbs of a CV: no present or past, so they explain nothing and say nothing done.
        infinitives: """
        administrar analizar aprender asistar atender ayudar cocinar colaborar comenzar completar contratar controlar
        coordinar crear cuidar cumplir dejar desarrollar dirigir disenar encargar ensenar escribir estudiar formar
        fundar gestionar graduar hablar impartar implementar iniciar introducir lanzar liderar mantener mejorar
        mostrar obtener ofrecer operar organizar participar permanecer permitir planificar poner preparar realizar
        reciber reducir responder salir supervisar terminar trabajar vender venir verificar viver
        """,
        /// Words of time, period and unit, and the months.
        time: """
        abril actual actualmente agosto ahora ano anos anterior antigua antiguo completa decada dia dias diciembre
        enero febrero hora horas hoy invierno jornada julio junio marzo mayo mes meses noviembre octubre otono parcial
        pasado presente primavera semana semanas septiembre setiembre temporada tiempo verano
        """,
        /// Words of level, and the CEFR codes.
        level: """
        a1 a2 avanzada avanzado b1 b2 basica basico bilingue c1 c2 elemental experta experto fluida fluido intermedia
        intermedio lengua materna nativa nativo nivel principiante
        """,
        /// Words of studying and graduating.
        studying: """
        academia colegio curso cursos diploma diplomatura doctorado escuela escuelas estudiante estudiantes estudios
        examen grado instituto licenciada licenciado licenciatura master primaria secundaria tesis titulo universidad
        universidades
        """,
        /// Prepositions and adverbs of time, and the conjunctions that join them: what a pure time phrase is made of, with years.
        timePhrase: """
        a actualmente ahora al antes de del desde despues durante e en entre hasta luego o partir y
        """,
        /// Words of graduating: a time phrase that holds one joins an education entry and gives its end date.
        graduating: """
        graduada graduado gradue graduo
        """,
        /// Words that go with them in a graduation phrase.
        graduationFrame: """
        me
        """,
        /// The present and past of to be, as written with accents: a verb that says something done on its own.
        beForms: """
        era erais eramos eran eras eres es estaba estabamos estaban estabas estais estamos estan estoy estuve
        estuvieron estuvimos estuviste estuvo está estábamos estáis están estás fue fueron fui fuimos fuiste fuisteis
        sois somos son soy éramos
        """,
        /// The auxiliaries of the perfect, as written with accents: a verb that says something done when a listed form follows it.
        auxiliaries: """
        ha habeis habia habiamos habian habias habéis había habíamos habían habías han has he hemos hube hubo teneis
        tenemos tengo tenia teniamos tenian tenias tenido teniendo tenéis tenía teníamos tenían tenías tiene tienen
        tienes tuve tuvieron tuvimos tuviste tuvo
        """,
        /// The forms of a verb that say another person than I, as written with accents, in the languages that drop the pronoun.
        otherPersons: """
        administra administrabais administrabamos administraban administrabas administrais administramos administran
        administraron administras administraste administrasteis administrábamos administráis administró analiza
        analizabais analizabamos analizaban analizabas analizais analizamos analizan analizaron analizas analizaste
        analizasteis analizábamos analizáis analizó aprende aprendeis aprendemos aprenden aprendes aprendiais
        aprendiamos aprendian aprendias aprendieron aprendimos aprendio aprendiste aprendisteis aprendió aprendéis
        aprendíais aprendíamos aprendían aprendías asista asistabais asistabamos asistaban asistabas asistais
        asistamos asistan asistaron asistas asistaste asistasteis asistábamos asistáis asistó atende atendeis
        atendemos atenden atendes atendiais atendiamos atendian atendias atendieron atendimos atendio atendiste
        atendisteis atendió atendéis atendíais atendíamos atendían atendías ayuda ayudabais ayudabamos ayudaban
        ayudabas ayudais ayudamos ayudan ayudaron ayudas ayudaste ayudasteis ayudábamos ayudáis ayudó cocina
        cocinabais cocinabamos cocinaban cocinabas cocinais cocinamos cocinan cocinaron cocinas cocinaste cocinasteis
        cocinábamos cocináis cocinó colabora colaborabais colaborabamos colaboraban colaborabas colaborais colaboramos
        colaboran colaboraron colaboras colaboraste colaborasteis colaborábamos colaboráis colaboró comenzo comenzó
        comienza completa completabais completabamos completaban completabas completais completamos completan
        completaron completas completaste completasteis completábamos completáis completó contrata contratabais
        contratabamos contrataban contratabas contratais contratamos contratan contrataron contratas contrataste
        contratasteis contratábamos contratáis contrató controla controlabais controlabamos controlaban controlabas
        controlais controlamos controlan controlaron controlas controlaste controlasteis controlábamos controláis
        controló convirtio convirtió coordina coordinabais coordinabamos coordinaban coordinabas coordinais
        coordinamos coordinan coordinaron coordinas coordinaste coordinasteis coordinábamos coordináis coordinó crea
        creabais creabamos creaban creabas creais creamos crean crearon creas creaste creasteis creábamos creáis creó
        cuida cuidabais cuidabamos cuidaban cuidabas cuidais cuidamos cuidan cuidaron cuidas cuidaste cuidasteis
        cuidábamos cuidáis cuidó cumple cumplen cumples cumpliais cumpliamos cumplian cumplias cumplieron cumplimos
        cumplio cumplis cumpliste cumplisteis cumplió cumplíais cumplíamos cumplían cumplías cumplís da deja dejabais
        dejabamos dejaban dejabas dejais dejamos dejan dejaron dejas dejaste dejasteis dejábamos dejáis dejó
        desarrolla desarrollabais desarrollabamos desarrollaban desarrollabas desarrollais desarrollamos desarrollan
        desarrollaron desarrollas desarrollaste desarrollasteis desarrollábamos desarrolláis desarrolló dio dirige
        dirigen diriges dirigieron dirigimos dirigio dirigió disena disenabais disenabamos disenaban disenabas
        disenais disenamos disenan disenaron disenas disenaste disenasteis diseña diseñabais diseñaban diseñabas
        diseñamos diseñan diseñaron diseñas diseñaste diseñasteis diseñábamos diseñáis diseñó encarga encargabais
        encargabamos encargaban encargabas encargais encargamos encargan encargaron encargas encargaste encargasteis
        encargábamos encargáis encargó ensena ensenabais ensenabamos ensenaban ensenabas ensenais ensenamos ensenan
        ensenaron ensenas ensenaste ensenasteis enseña enseñabais enseñaban enseñabas enseñamos enseñan enseñaron
        enseñas enseñaste enseñasteis enseñábamos enseñáis enseñó erais eramos eran eras eres es escribe escriben
        escribes escribiais escribiamos escribian escribias escribieron escribimos escribio escribis escribiste
        escribisteis escribió escribíais escribíamos escribían escribías escribís esta estabamos estaban estabas
        estais estamos estan estas estudia estudiabais estudiabamos estudiaban estudiabas estudiais estudiamos
        estudian estudiaron estudias estudiaste estudiasteis estudiábamos estudiáis estudió estuvieron estuvimos
        estuviste estuvo está estábamos estáis están estás forma formabais formabamos formaban formabas formais
        formamos forman formaron formas formaste formasteis formábamos formáis formó fue fueron fuimos fuiste fuisteis
        funda fundabais fundabamos fundaban fundabas fundais fundamos fundan fundaron fundas fundaste fundasteis
        fundábamos fundáis fundó gestiona gestionabais gestionabamos gestionaban gestionabas gestionais gestionamos
        gestionan gestionaron gestionas gestionaste gestionasteis gestionábamos gestionáis gestionó gradua graduo
        graduó gradúa ha habeis habiamos habian habias habla hablabais hablabamos hablaban hablabas hablais hablamos
        hablan hablaron hablas hablaste hablasteis hablábamos habláis habló habéis habíamos habían habías han has
        hemos hubo imparta impartabais impartabamos impartaban impartabas impartais impartamos impartan impartaron
        impartas impartaste impartasteis impartábamos impartáis impartó implementa implementabais implementabamos
        implementaban implementabas implementais implementamos implementan implementaron implementas implementaste
        implementasteis implementábamos implementáis implementó incorporo incorporó inicia iniciabais iniciabamos
        iniciaban iniciabas iniciais iniciamos inician iniciaron inicias iniciaste iniciasteis iniciábamos iniciáis
        inició introduce introdujo lanza lanzabais lanzabamos lanzaban lanzabas lanzais lanzamos lanzan lanzaron
        lanzas lanzaste lanzasteis lanzábamos lanzáis lanzó lidera liderabais liderabamos lideraban liderabas liderais
        lideramos lideran lideraron lideras lideraste liderasteis liderábamos lideráis lideró mantiene mantuvo mejora
        mejorabais mejorabamos mejoraban mejorabas mejorais mejoramos mejoran mejoraron mejoras mejoraste mejorasteis
        mejorábamos mejoráis mejoró mostra mostrabais mostrabamos mostraban mostrabas mostrais mostramos mostran
        mostraron mostras mostraste mostrasteis mostrábamos mostráis mostró obtiene obtuvo ocupo ocupó ofrece ofreceis
        ofrecemos ofrecen ofreces ofreciais ofreciamos ofrecian ofrecias ofrecieron ofrecimos ofrecio ofreciste
        ofrecisteis ofreció ofrecéis ofrecíais ofrecíamos ofrecían ofrecías opera operabais operabamos operaban
        operabas operais operamos operan operaron operas operaste operasteis operábamos operáis operó organiza
        organizabais organizabamos organizaban organizabas organizais organizamos organizan organizaron organizas
        organizaste organizasteis organizábamos organizáis organizó participa participabais participabamos
        participaban participabas participais participamos participan participaron participas participaste
        participasteis participábamos participáis participó permanece permanecio permaneció permite permiten permites
        permitiais permitiamos permitian permitias permitieron permitimos permitio permitis permitiste permitisteis
        permitió permitíais permitíamos permitían permitías permitís planifica planificabais planificabamos
        planificaban planificabas planificais planificamos planifican planificaron planificas planificaste
        planificasteis planificábamos planificáis planificó pone prepara preparabais preparabamos preparaban
        preparabas preparais preparamos preparan prepararon preparas preparaste preparasteis preparábamos preparáis
        preparó puso realiza realizabais realizabamos realizaban realizabas realizais realizamos realizan realizaron
        realizas realizaste realizasteis realizábamos realizáis realizó recibe recibeis recibemos reciben recibes
        recibiais recibiamos recibian recibias recibieron recibimos recibio recibiste recibisteis recibió recibéis
        recibíais recibíamos recibían recibías reduce redujo responde respondeis respondemos responden respondes
        respondiais respondiamos respondian respondias respondieron respondimos respondio respondiste respondisteis
        respondió respondéis respondíais respondíamos respondían respondías sale salio salió sois somos son supervisa
        supervisabais supervisabamos supervisaban supervisabas supervisais supervisamos supervisan supervisaron
        supervisas supervisaste supervisasteis supervisábamos supervisáis supervisó teneis tenemos teniamos tenian
        tenias tenéis teníamos tenían tenías termina terminabais terminabamos terminaban terminabas terminais
        terminamos terminan terminaron terminas terminaste terminasteis terminábamos termináis terminó tiene tienen
        tienes trabaja trabajabais trabajabamos trabajaban trabajabas trabajais trabajamos trabajan trabajaron
        trabajas trabajaste trabajasteis trabajábamos trabajáis trabajó tuvieron tuvimos tuviste tuvo usa usabais
        usabamos usaban usabas usais usamos usan usaron usas usaste usasteis usábamos usáis usó vende vendeis vendemos
        venden vendes vendiais vendiamos vendian vendias vendieron vendimos vendio vendiste vendisteis vendió vendéis
        vendíais vendíamos vendían vendías verifica verificabais verificabamos verificaban verificabas verificais
        verificamos verifican verificaron verificas verificaste verificasteis verificábamos verificáis verificó viene
        vino vive viveis vivemos viven vives viviais viviamos vivian vivias vivieron vivimos vivio viviste vivisteis
        vivió vivéis vivíais vivíamos vivían vivías éramos
        """,
        /// The forms of a verb that a noun can be the subject of, as written with accents, in the languages that drop the pronoun.
        thirdPersons: """
        administra administraba administraban administran administraron administró analiza analizaba analizaban
        analizan analizaron analizó aprende aprenden aprendieron aprendió aprendía aprendían asista asistaba asistaban
        asistan asistaron asistó atende atenden atendieron atendió atendía atendían ayuda ayudaba ayudaban ayudan
        ayudaron ayudó cocina cocinaba cocinaban cocinan cocinaron cocinó colabora colaboraba colaboraban colaboran
        colaboraron colaboró comenzó comienza completa completaba completaban completan completaron completó contrata
        contrataba contrataban contratan contrataron contrató controla controlaba controlaban controlan controlaron
        controló convirtió coordina coordinaba coordinaban coordinan coordinaron coordinó crea creaba creaban crean
        crearon creó cuida cuidaba cuidaban cuidan cuidaron cuidó cumple cumplen cumplieron cumplió cumplía cumplían
        da deja dejaba dejaban dejan dejaron dejó desarrolla desarrollaba desarrollaban desarrollan desarrollaron
        desarrolló dio dirige dirigen dirigieron dirigió diseña diseñaba diseñaban diseñan diseñaron diseñó encarga
        encargaba encargaban encargan encargaron encargó enseña enseñaba enseñaban enseñan enseñaron enseñó era eran
        es escribe escriben escribieron escribió escribía escribían estaba estaban estudia estudiaba estudiaban
        estudian estudiaron estudió estuvieron estuvo está están forma formaba formaban forman formaron formó fue
        fueron funda fundaba fundaban fundan fundaron fundó gestiona gestionaba gestionaban gestionan gestionaron
        gestionó graduó gradúa ha habla hablaba hablaban hablan hablaron habló había habían han hubo imparta impartaba
        impartaban impartan impartaron impartó implementa implementaba implementaban implementan implementaron
        implementó incorporó inicia iniciaba iniciaban inician iniciaron inició introduce introdujo lanza lanzaba
        lanzaban lanzan lanzaron lanzó lidera lideraba lideraban lideran lideraron lideró mantiene mantuvo mejora
        mejoraba mejoraban mejoran mejoraron mejoró mostra mostraba mostraban mostran mostraron mostró obtiene obtuvo
        ocupó ofrece ofrecen ofrecieron ofreció ofrecía ofrecían opera operaba operaban operan operaron operó organiza
        organizaba organizaban organizan organizaron organizó participa participaba participaban participan
        participaron participó permanece permaneció permite permiten permitieron permitió permitía permitían planifica
        planificaba planificaban planifican planificaron planificó pone prepara preparaba preparaban preparan
        prepararon preparó puso realiza realizaba realizaban realizan realizaron realizó recibe reciben recibieron
        recibió recibía recibían reduce redujo responde responden respondieron respondió respondía respondían sale
        salió son supervisa supervisaba supervisaban supervisan supervisaron supervisó tenía tenían termina terminaba
        terminaban terminan terminaron terminó tiene tienen trabaja trabajaba trabajaban trabajan trabajaron trabajó
        tuvieron tuvo usa usaba usaban usan usaron usó vende venden vendieron vendió vendía vendían verifica
        verificaba verificaban verifican verificaron verificó viene vino vive viven vivieron vivió vivía vivían
        """,
        /// Everyday verbs in the third person, as written with accents: no CV verbs, but the ones a noun before them is the subject of.
        everydayVerbs: """
        adora adoraba adoraban adoran adoraron adoró ama amaba amaban aman amaron amó aprecia apreciaba apreciaban
        aprecian apreciaron apreció baila bailaba bailaban bailan bailaron bailó bebe beben bebieron bebió bebía
        bebían busca buscaba buscaban buscan buscaron buscó camina caminaba caminaban caminan caminaron caminó canta
        cantaba cantaban cantan cantaron cantó coleciona colecionaba colecionaban colecionan colecionaron colecionó
        conduce conducen conducía conducían condujeron condujo conoce conocen conocieron conoció conocía conocían
        corre corren corrieron corrió corría corrían cree creen creieron creió creía creían decía decían dice dicen
        dijeron dijo disfruta disfrutaba disfrutaban disfrutan disfrutaron disfrutó domina dominaba dominaban dominan
        dominaron dominó dormía dormían duerme duermen durmieron durmió escribe escriben escribieron escribió escribía
        escribían escucha escuchaba escuchaban escuchan escucharon escuchó gusta gustaba gustaban gustan gustaron
        gustó habla hablaba hablaban hablan hablaron habló hace hacen hacía hacían hicieron hizo iba iban juega juegan
        jugaba jugaban jugaron jugó lee leen leyeron leyó leía leían maneja manejaba manejaban manejan manejaron
        manejó muda mudaba mudaban mudan mudaron mudó odia odiaba odiaban odian odiaron odió pedalea pedaleaba
        pedaleaban pedalean pedalearon pedaleó pensaba pensaban pensaron pensó piensa piensan pinta pintaba pintaban
        pintan pintaron pintó podía podían practica practicaba practicaban practican practicaron practicó prefería
        preferían prefiere prefieren prefirieron prefirió pudieron pudo puede pueden queda quedaba quedaban quedan
        quedaron quedó recibe reciben recibieron recibió recibía recibían reside residen residieron residió residía
        residían sabe saben sabía sabían sale salen salieron salió salía salían soñaba soñaban soñaron soñó sueña
        sueñan supieron supo tenía tenían tiene tienen tuvieron tuvo usa usaba usaban usan usaron usó van ven venía
        venían veía veían viaja viajaba viajaban viajan viajaron viajó viene vienen vieron vinieron vino vio vive
        viven vivieron vivió vivía vivían
        """,
        /// Words of negation, doubt or degree, wish or intention, future and condition: in no other list.
        modality: """
        sería serías seríamos seríais serían haria harias hariamos hariais harian tendria tendrias tendriamos tendriais tendrian
        encantaria encantarian
        sueno_con lo_sueno
        administrara administraran administraras administrare administrareis administraremos administraria
        administrariais administrariamos administrarian administrarias analizara analizaran analizaras analizare
        analizareis analizaremos analizaria analizariais analizariamos analizarian analizarias apenas aprendera
        aprenderan aprenderas aprendere aprendereis aprenderemos aprenderia aprenderiais aprenderiamos aprenderian
        aprenderias asistara asistaran asistaras asistare asistareis asistaremos asistaria asistariais asistariamos
        asistarian asistarias atendera atenderan atenderas atendere atendereis atenderemos atenderia atenderiais
        atenderiamos atenderian atenderias ayudara ayudaran ayudaras ayudare ayudareis ayudaremos ayudaria ayudariais
        ayudariamos ayudarian ayudarias casi cocinara cocinaran cocinaras cocinare cocinareis cocinaremos cocinaria
        cocinariais cocinariamos cocinarian cocinarias colaborara colaboraran colaboraras colaborare colaborareis
        colaboraremos colaboraria colaborariais colaborariamos colaborarian colaborarias completara completaran
        completaras completareis completaremos completaria completariais completariamos completarian completarias
        contratara contrataran contrataras contratare contratareis contrataremos contrataria contratariais
        contratariamos contratarian contratarias controlara controlaran controlaras controlare controlareis
        controlaremos controlaria controlariais controlariamos controlarian controlarias coordinara coordinaran
        coordinaras coordinareis coordinaremos coordinaria coordinariais coordinariamos coordinarian coordinarias
        creara crearan crearas creareis crearemos crearia creariais creariamos crearian crearias cuidara cuidaran
        cuidaras cuidare cuidareis cuidaremos cuidaria cuidariais cuidariamos cuidarian cuidarias cumplira cumpliran
        cumpliras cumplire cumplireis cumpliremos cumpliria cumpliriais cumpliriamos cumplirian cumplirias debe
        deberia debo dejara dejaran dejaras dejare dejareis dejaremos dejaria dejariais dejariamos dejarian dejarias
        desarrollara desarrollaran desarrollaras desarrollare desarrollareis desarrollaremos desarrollaria
        desarrollariais desarrollariamos desarrollarian desarrollarias desea deseo disenara disenaran disenaras
        disenare disenareis disenaremos disenaria disenariais disenariamos disenarian disenarias encargara encargaran
        encargaras encargare encargareis encargaremos encargaria encargariais encargariamos encargarian encargarias
        ensenara ensenaran ensenaras ensenare ensenareis ensenaremos ensenaria ensenariais ensenariamos ensenarian
        ensenarias escribira escribiran escribiras escribire escribireis escribiremos escribiria escribiriais
        escribiriamos escribirian escribirias espera esperamos esperas espero estudiara estudiaran estudiaras
        estudiare estudiareis estudiaremos estudiaria estudiariais estudiariamos estudiarian estudiarias formara
        formaran formaras formareis formaremos formaria formariais formariamos formarian formarias fundara fundaran
        fundaras fundare fundareis fundaremos fundaria fundariais fundariamos fundarian fundarias gestionara
        gestionaran gestionaras gestionare gestionareis gestionaremos gestionaria gestionariais gestionariamos
        gestionarian gestionarias gustaria hablara hablaran hablaras hablare hablareis hablaremos hablaria hablariais
        hablariamos hablarian hablarias habra habre impartara impartaran impartaras impartare impartareis impartaremos
        impartaria impartariais impartariamos impartarian impartarias implementara implementaran implementaras
        implementare implementareis implementaremos implementaria implementariais implementariamos implementarian
        implementarias iniciara iniciaran iniciaras iniciare iniciareis iniciaremos iniciaria iniciariais iniciariamos
        iniciarian iniciarias jamas lanzara lanzaran lanzaras lanzare lanzareis lanzaremos lanzaria lanzariais
        lanzariamos lanzarian lanzarias liderara lideraran lideraras liderare liderareis lideraremos lideraria
        liderariais liderariamos liderarian liderarias mejorara mejoraran mejoraras mejorare mejorareis mejoraremos
        mejoraria mejorariais mejorariamos mejorarian mejorarias mostrara mostraran mostraras mostrareis mostraremos
        mostraria mostrariais mostrariamos mostrarian mostrarias nada nadie ni ningun ninguna ninguno no nunca
        ofrecera ofreceran ofreceras ofrecere ofrecereis ofreceremos ofreceria ofreceriais ofreceriamos ofrecerian
        ofrecerias operara operaran operaras operare operareis operaremos operaria operariais operariamos operarian
        operarias organizara organizaran organizaras organizare organizareis organizaremos organizaria organizariais
        organizariamos organizarian organizarias parcialmente participara participaran participaras participare
        participareis participaremos participaria participariais participariamos participarian participarias permitira
        permitiran permitiras permitire permitireis permitiremos permitiria permitiriais permitiriamos permitirian
        permitirias planeo planificara planificaran planificaras planificare planificareis planificaremos planificaria
        planificariais planificariamos planificarian planificarias podemos podria posiblemente preparara prepararan
        prepararas preparareis prepararemos prepararia preparariais preparariamos prepararian prepararias pretendo
        probablemente puede pueden puedo queremos queria querria quiere quieren quieres quiero quisiera quiza quizas
        realizara realizaran realizaras realizare realizareis realizaremos realizaria realizariais realizariamos
        realizarian realizarias recibera reciberan reciberas recibere recibereis reciberemos reciberia reciberiais
        reciberiamos reciberian reciberias respondera responderan responderas respondere respondereis responderemos
        responderia responderiais responderiamos responderian responderias sera seran seras sere seremos si sin
        supervisara supervisaran supervisaras supervisare supervisareis supervisaremos supervisaria supervisariais
        supervisariamos supervisarian supervisarias tampoco tendra tendre terminara terminaran terminaras terminareis
        terminaremos terminaria terminariais terminariamos terminarian terminarias trabajara trabajaran trabajaras
        trabajare trabajareis trabajaremos trabajaria trabajariais trabajariamos trabajarian trabajarias usara usaran
        usaras usareis usaremos usaria usariais usariamos usarian usarias vendera venderan venderas vendereis
        venderemos venderia venderiais venderiamos venderian venderias verificara verificaran verificaras verificareis
        verificaremos verificaria verificariais verificariamos verificarian verificarias vivera viveran viveras
        vivereis viveremos viveria viveriais viveriamos viverian viverias
        """
    )
}
