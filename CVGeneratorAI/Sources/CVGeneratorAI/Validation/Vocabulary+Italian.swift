/// The closed vocabulary of Italian (ADR 0023), written as `DescriptionText.normalized` writes a word: lower case,
/// without accents, an elided article as a word of its own; but for the forms of to be and the auxiliaries, which keep them.
extension Vocabulary {
    static let italian = Words(
        /// Articles, prepositions, pronouns, auxiliaries, conjunctions and subordinators.
        function: """
        a abbiamo ad adesso agli ai al all alla alle allo altra altre altri altro anche ancora avemmo avendo avere
        aveste avesti avete aveva avevamo avevano avevate avevi avevo avuta avute avuti avuto c che chi ci cio coi col
        come con cosi cui d da dagli dai dal dall dalla dalle dallo degli dei del dell della delle dello di dopo dove
        e ebbe ebbero ebbi ed era erano eravamo eravate eri ero essendo essere fa facciamo faccio facendo fai fanno
        fare fate fatta fatte fatti fatto fece feci foste fosti fra fu fui fummo furono gia gli ha hai hanno ho i il
        in io j l la le li lo m ma me mentre mi mia mie miei mio molta molte molti molto negli nei nel nell nella
        nelle nello noi nostra nostre nostri nostro o ogni ora per perche pero poi presso prima pure qu qua quale
        quali quando quella quelle quelli quello questa queste questi questo qui s sei sempre siamo siete sono stata
        state stati stato stessa stesse stessi stesso su sugli sui sul sull sulla sulle sullo ti tra tu tua tuo tutta
        tutte tutti tutto un una uno v vi voi vostra vostro
        """,
        /// Verbs of a CV: their inflected forms, the infinitives set apart.
        verbs: """
        aiuta aiutai aiutammo aiutando aiutano aiutarono aiutaste aiutasti aiutata aiutate aiutati aiutato aiutava
        aiutavamo aiutavano aiutavate aiutavi aiutavo aiuti aiutiamo aiuto amministra amministrai amministrammo
        amministrando amministrano amministrarono amministraste amministrasti amministrata amministrate amministrati
        amministrato amministrava amministravamo amministravano amministravate amministravi amministravo amministri
        amministriamo amministro analizza analizzai analizzammo analizzando analizzano analizzarono analizzaste
        analizzasti analizzata analizzate analizzati analizzato analizzava analizzavamo analizzavano analizzavate
        analizzavi analizzavo analizzi analizziamo analizzo assicura assicurai assicurammo assicurando assicurano
        assicurarono assicuraste assicurasti assicurata assicurate assicurati assicurato assicurava assicuravamo
        assicuravano assicuravate assicuravi assicuravo assicuri assicuriamo assicuro assume assumendo assumeva
        assumevo assumiamo assumo assumono assunse assunsi assunta assunte assunti assunto aumenta aumentai aumentammo
        aumentando aumentano aumentarono aumentaste aumentasti aumentata aumentate aumentati aumentato aumentava
        aumentavamo aumentavano aumentavate aumentavi aumentavo aumenti aumentiamo aumento collabora collaborai
        collaborammo collaborando collaborano collaborarono collaboraste collaborasti collaborata collaborate
        collaborati collaborato collaborava collaboravamo collaboravano collaboravate collaboravi collaboravo
        collabori collaboriamo collaboro comincia cominciai cominciammo cominciando cominciano cominciarono
        cominciaste cominciasti cominciata cominciate cominciati cominciato cominciava cominciavamo cominciavano
        cominciavate cominciavi cominciavo comincii cominciiamo comincio completa completai completammo completando
        completano completarono completaste completasti completata completate completati completato completava
        completavamo completavano completavate completavi completavo completi completiamo completo consegue consegui
        conseguita conseguito conseguo contribue contribuendo contribui contribuiamo contribuii contribuimmo
        contribuirono contribuisce contribuisci contribuisco contribuiscono contribuiste contribuisti contribuita
        contribuite contribuiti contribuito contribuiva contribuivamo contribuivano contribuivate contribuivi
        contribuivo contribuo contribuono controlla controllai controllammo controllando controllano controllarono
        controllaste controllasti controllata controllate controllati controllato controllava controllavamo
        controllavano controllavate controllavi controllavo controlli controlliamo controllo coordina coordinai
        coordinammo coordinando coordinano coordinarono coordinaste coordinasti coordinata coordinate coordinati
        coordinato coordinava coordinavamo coordinavano coordinavate coordinavi coordinavo coordini coordiniamo
        coordino costrue costruendo costrui costruiamo costruii costruimmo costruirono costruisce costruisci
        costruisco costruiscono costruiste costruisti costruita costruite costruiti costruito costruiva costruivamo
        costruivano costruivate costruivi costruivo costruo costruono crea creai creammo creando creano crearono
        creaste creasti creata create creati creato creava creavamo creavano creavate creavi creavo crei creiamo creo
        cresce crescei crescemmo crescendo crescerono cresceste crescesti crescete crescette crescettero crescetti
        cresceva crescevamo crescevano crescevate crescevi crescevo cresci cresciamo cresco crescono crescuta crescute
        crescuti crescuto cucina cucinai cucinammo cucinando cucinano cucinarono cucinaste cucinasti cucinata cucinate
        cucinati cucinato cucinava cucinavamo cucinavano cucinavate cucinavi cucinavo cucini cuciniamo cucino cura
        curai curammo curando curano curarono curaste curasti curata curate curati curato curava curavamo curavano
        curavate curavi curavo curi curiamo curo diploma diplomai diplomammo diplomando diplomano diplomarono
        diplomaste diplomasti diplomata diplomate diplomati diplomato diplomava diplomavamo diplomavano diplomavate
        diplomavi diplomavo diplomi diplomiamo diplomo diresse diressi diretta diretto dirige dirigendo dirigeva
        dirigevo dirigi dirigiamo dirigo dirigono diventa diventai diventando diventata diventato diventavo divento
        entra entrai entrata entrato entro fine finendo fini finiamo finii finimmo finirono finisce finisci finisco
        finiscono finiste finisti finita finite finiti finito finiva finivamo finivano finivate finivi finivo fino
        finono forma formai formammo formando formano formarono formaste formasti formata formate formati formato
        formava formavamo formavano formavate formavi formavo formi formiamo formo frequenta frequentai frequentammo
        frequentando frequentano frequentarono frequentaste frequentasti frequentata frequentate frequentati
        frequentato frequentava frequentavamo frequentavano frequentavate frequentavi frequentavo frequenti
        frequentiamo frequento geste gestendo gesti gestiamo gestii gestimmo gestirono gestisce gestisci gestisco
        gestiscono gestiste gestisti gestita gestite gestiti gestito gestiva gestivamo gestivano gestivate gestivi
        gestivo gesto gestono inizia iniziai iniziammo iniziando iniziano iniziarono iniziaste iniziasti iniziata
        iniziate iniziati iniziato iniziava iniziavamo iniziavano iniziavate iniziavi iniziavo inizii iniziiamo inizio
        insegna insegnai insegnammo insegnando insegnano insegnarono insegnaste insegnasti insegnata insegnate
        insegnati insegnato insegnava insegnavamo insegnavano insegnavate insegnavi insegnavo insegni insegniamo
        insegno introdotta introdotto introduce introducendo introduco istrue istruendo istrui istruiamo istruii
        istruimmo istruirono istruisce istruisci istruisco istruiscono istruiste istruisti istruita istruite istruiti
        istruito istruiva istruivamo istruivano istruivate istruivi istruivo istruo istruono lascia lasciai lasciammo
        lasciando lasciano lasciarono lasciaste lasciasti lasciata lasciate lasciati lasciato lasciava lasciavamo
        lasciavano lasciavate lasciavi lasciavo lascii lasciiamo lascio laureai laureandomi laureata laureato laureo
        lavora lavorai lavorammo lavorando lavorano lavorarono lavoraste lavorasti lavorata lavorate lavorati lavorato
        lavorava lavoravamo lavoravano lavoravate lavoravi lavoravo lavori lavoriamo lavoro mantengo mantenne mantenni
        mantenuta mantenuto mantiene migliora migliorai migliorammo migliorando migliorano migliorarono miglioraste
        migliorasti migliorata migliorate migliorati migliorato migliorava miglioravamo miglioravano miglioravate
        miglioravi miglioravo migliori miglioriamo miglioro mostra mostrai mostrammo mostrando mostrano mostrarono
        mostraste mostrasti mostrata mostrate mostrati mostrato mostrava mostravamo mostravano mostravate mostravi
        mostravo mostri mostriamo mostro occupa occupai occupammo occupando occupandomi occupandosi occupano
        occuparono occupaste occupasti occupata occupate occupati occupato occupava occupavamo occupavano occupavate
        occupavi occupavo occupi occupiamo occupo organizza organizzai organizzammo organizzando organizzano
        organizzarono organizzaste organizzasti organizzata organizzate organizzati organizzato organizzava
        organizzavamo organizzavano organizzavate organizzavi organizzavo organizzi organizziamo organizzo ottengo
        ottenne ottenni ottenuta ottenuto ottiene parla parlai parlammo parlando parlano parlarono parlaste parlasti
        parlata parlate parlati parlato parlava parlavamo parlavano parlavate parlavi parlavo parli parliamo parlo
        parte partecipa partecipai partecipammo partecipando partecipano parteciparono partecipaste partecipasti
        partecipata partecipate partecipati partecipato partecipava partecipavamo partecipavano partecipavate
        partecipavi partecipavo partecipi partecipiamo partecipo partendo parti partiamo partii partimmo partirono
        partiste partisti partita partite partiti partito partiva partivamo partivano partivate partivi partivo parto
        partono pianifica pianificai pianificammo pianificando pianificano pianificarono pianificaste pianificasti
        pianificata pianificate pianificati pianificato pianificava pianificavamo pianificavano pianificavate
        pianificavi pianificavo pianifici pianificiamo pianifico prende prendei prendemmo prendendo prenderono
        prendeste prendesti prendete prendette prendettero prendetti prendeva prendevamo prendevano prendevate
        prendevi prendevo prendi prendiamo prendo prendono prenduta prendute prenduti prenduto prepara preparai
        preparammo preparando preparano prepararono preparaste preparasti preparata preparate preparati preparato
        preparava preparavamo preparavano preparavate preparavi preparavo prepari prepariamo preparo presenta
        presentai presentammo presentando presentano presentarono presentaste presentasti presentata presentate
        presentati presentato presentava presentavamo presentavano presentavate presentavi presentavo presenti
        presentiamo presento progetta progettai progettammo progettando progettano progettarono progettaste
        progettasti progettata progettate progettati progettato progettava progettavamo progettavano progettavate
        progettavi progettavo progetti progettiamo progetto realizza realizzai realizzammo realizzando realizzano
        realizzarono realizzaste realizzasti realizzata realizzate realizzati realizzato realizzava realizzavamo
        realizzavano realizzavate realizzavi realizzavo realizzi realizziamo realizzo riceve ricevei ricevemmo
        ricevendo riceverono riceveste ricevesti ricevete ricevette ricevettero ricevetti riceveva ricevevamo
        ricevevano ricevevate ricevevi ricevevo ricevi riceviamo ricevo ricevono ricevuta ricevute ricevuti ricevuto
        ricoperta ricoperto ricopre ricoprendo ricopriva ricoprivo ricopro ridotta ridotto riduce riducendo riduco
        riorganizza riorganizzai riorganizzammo riorganizzando riorganizzano riorganizzarono riorganizzaste
        riorganizzasti riorganizzata riorganizzate riorganizzati riorganizzato riorganizzava riorganizzavamo
        riorganizzavano riorganizzavate riorganizzavi riorganizzavo riorganizzi riorganizziamo riorganizzo risponde
        rispondei rispondemmo rispondendo risponderono rispondeste rispondesti rispondete rispondette rispondettero
        rispondetti rispondeva rispondevamo rispondevano rispondevate rispondevi rispondevo rispondi rispondiamo
        rispondo rispondono risponduta rispondute risponduti risponduto segue seguendo segui seguiamo seguii seguimmo
        seguirono seguiste seguisti seguita seguite seguiti seguito seguiva seguivamo seguivano seguivate seguivi
        seguivo seguo seguono serve servendo servi serviamo servii servimmo servirono serviste servisti servita
        servite serviti servito serviva servivamo servivano servivate servivi servivo servo servono sostitue
        sostituendo sostitui sostituiamo sostituii sostituimmo sostituirono sostituisce sostituisci sostituisco
        sostituiscono sostituiste sostituisti sostituita sostituite sostituiti sostituito sostituiva sostituivamo
        sostituivano sostituivate sostituivi sostituivo sostituo sostituono studia studiai studiammo studiando
        studiano studiarono studiaste studiasti studiata studiate studiati studiato studiava studiavamo studiavano
        studiavate studiavi studiavo studii studiiamo studio supervisiona supervisionai supervisionammo
        supervisionando supervisionano supervisionarono supervisionaste supervisionasti supervisionata supervisionate
        supervisionati supervisionato supervisionava supervisionavamo supervisionavano supervisionavate supervisionavi
        supervisionavo supervisioni supervisioniamo supervisiono sviluppa sviluppai sviluppammo sviluppando sviluppano
        svilupparono sviluppaste sviluppasti sviluppata sviluppate sviluppati sviluppato sviluppava sviluppavamo
        sviluppavano sviluppavate sviluppavi sviluppavo sviluppi sviluppiamo sviluppo svolge svolgendo svolgeva
        svolgevo svolgo svolta svolto termina terminai terminammo terminando terminano terminarono terminaste
        terminasti terminata terminate terminati terminato terminava terminavamo terminavano terminavate terminavi
        terminavo termini terminiamo termino torna tornata tornato torno trasferendomi trasferisco trasferita
        trasferito trasforma trasformai trasformammo trasformando trasformano trasformarono trasformaste trasformasti
        trasformata trasformate trasformati trasformato trasformava trasformavamo trasformavano trasformavate
        trasformavi trasformavo trasformi trasformiamo trasformo usa usai usammo usando usano usare usarono usaste
        usasti usata usate usati usato usava usavamo usavano usavate usavi usavo usi usiamo uso vende vendei vendemmo
        vendendo venderono vendeste vendesti vendete vendette vendettero vendetti vendeva vendevamo vendevano
        vendevate vendevi vendevo vendi vendiamo vendo vendono venduta vendute venduti venduto vengo venuta venuto
        verifica verificai verificammo verificando verificano verificarono verificaste verificasti verificata
        verificate verificati verificato verificava verificavamo verificavano verificavate verificavi verificavo
        verifici verificiamo verifico viene vive vivei vivemmo vivendo viverono viveste vivesti vivete vivette
        vivettero vivetti viveva vivevamo vivevano vivevate vivevi vivevo vivi viviamo vivo vivono vivuta vivute
        vivuti vivuto
        """,
        /// The infinitives of the verbs of a CV: no present or past, so they explain nothing and say nothing done.
        infinitives: """
        aiutare amministrare analizzare assicurare assumere aumentare collaborare cominciare completare conseguire
        contribuire controllare coordinare costruire creare crescere cucinare curare diplomare diplomarmi dirigere
        diventare entrare finire formare frequentare gestire iniziare insegnare introdurre istruire lasciare laurearmi
        laurearsi lavorare mantenere migliorare mostrare occupare occuparmi occuparsi organizzare ottenere parlare
        partecipare partire pianificare prendere preparare presentare progettare realizzare ricevere ricoprire ridurre
        riorganizzare rispondere seguire servire sostituire studiare supervisionare sviluppare svolgere terminare
        tornare trasferirmi trasferirsi trasformare vendere venire verificare vivere
        """,
        /// Words of time, period and unit, and the months.
        time: """
        agosto anni anno aprile attualmente autunno corrente decennio dicembre estate ex febbraio fino gennaio giorni
        giorno giugno inverno luglio maggio marzo mese mesi novembre oggi ore ottobre passato precedente presente
        primavera scorsa scorso settembre settimana settimane stagione tuttora
        """,
        /// Words of level, and the CEFR codes.
        level: """
        a1 a2 avanzata avanzato b1 b2 base bilingue c1 c2 elementare esperta esperto fluente fluenti intermedia
        intermedio livello madrelingua nativa nativo principiante
        """,
        /// Words of studying and graduating.
        studying: """
        accademia corsi corso diploma diplomata diplomato diplomi dottorato esame esami istituti istituto laurea
        laurearsi laureata laureate laureati laureato lauree lezione lezioni liceo master primaria scuola scuole
        secondaria studente studentessa studenti studi studio tesi universita
        """,
        /// Prepositions and adverbs of time, and the conjunctions that join them: what a pure time phrase is made of, with years.
        timePhrase: """
        ad adesso agli ai al all alla alle allo attualmente dagli dai dal dall dalla dalle dallo dopo e ed fino negli
        nei nel nell nella nelle nello o oggi partire poi prima tuttora
        """,
        /// Words of graduating: a time phrase that holds one joins an education entry and gives its end date.
        graduating: """
        completata completato conclusa concluso conseguii conseguita conseguito diplomata diplomate diplomati diplomato
        laureai laureata laureate laureati laureato laureo terminai terminata terminato
        """,
        /// Words that go with them in a graduation phrase.
        graduationFrame: """
        corso gli ha ho i il l mi miei mio sono studi
        """,
        /// The present and past of to be, as written with accents: a verb that says something done on its own.
        beForms: """
        era erano eravamo eravate eri ero essendo foste fosti fu fui fummo furono sei siamo siete sono stata state
        stati stato è
        """,
        /// The auxiliaries of the perfect, as written with accents: a verb that says something done when a listed form follows it.
        auxiliaries: """
        abbiamo avemmo avendo aveste avesti avete aveva avevamo avevano avevate avevi avevo avuto ebbe ebbero ebbi ha
        hai hanno ho
        """,
        /// The forms of a verb that say another person than I, as written with accents, in the languages that drop the pronoun.
        otherPersons: """
        abbiamo aiuta aiutammo aiutano aiutarono aiutaste aiutasti aiutate aiutava aiutavamo aiutavano aiutavate
        aiutavi aiuti aiutiamo aiutò amministra amministrammo amministrano amministrarono amministraste amministrasti
        amministrate amministrava amministravamo amministravano amministravate amministravi amministri amministriamo
        amministrò analizza analizzammo analizzano analizzarono analizzaste analizzasti analizzate analizzava
        analizzavamo analizzavano analizzavate analizzavi analizzi analizziamo analizzò assicura assicurammo
        assicurano assicurarono assicuraste assicurasti assicurate assicurava assicuravamo assicuravano assicuravate
        assicuravi assicuri assicuriamo assicurò assume assumeva assumiamo assumono assunse aumenta aumentammo
        aumentano aumentarono aumentaste aumentasti aumentate aumentava aumentavamo aumentavano aumentavate aumentavi
        aumenti aumentiamo aumentò avemmo aveste avesti avete aveva avevamo avevano avevate avevi collabora
        collaborammo collaborano collaborarono collaboraste collaborasti collaborate collaborava collaboravamo
        collaboravano collaboravate collaboravi collabori collaboriamo collaborò comincia cominciammo cominciano
        cominciarono cominciaste cominciasti cominciate cominciava cominciavamo cominciavano cominciavate cominciavi
        comincii cominciiamo cominciò completa completammo completano completarono completaste completasti completate
        completava completavamo completavano completavate completavi completi completiamo completò consegue consegui
        contribue contribui contribuiamo contribuimmo contribuirono contribuisce contribuisci contribuiscono
        contribuiste contribuisti contribuite contribuiva contribuivamo contribuivano contribuivate contribuivi
        contribuono contribuì controlla controllammo controllano controllarono controllaste controllasti controllate
        controllava controllavamo controllavano controllavate controllavi controlli controlliamo controllò coordina
        coordinammo coordinano coordinarono coordinaste coordinasti coordinate coordinava coordinavamo coordinavano
        coordinavate coordinavi coordini coordiniamo coordinò costrue costrui costruiamo costruimmo costruirono
        costruisce costruisci costruiscono costruiste costruisti costruite costruiva costruivamo costruivano
        costruivate costruivi costruono costruì crea creammo creano crearono creaste creasti create creava creavamo
        creavano creavate creavi crei creiamo cresce crescemmo crescerono cresceste crescesti crescete crescette
        crescettero cresceva crescevamo crescevano crescevate crescevi cresci cresciamo crescono creò cucina cucinammo
        cucinano cucinarono cucinaste cucinasti cucinate cucinava cucinavamo cucinavano cucinavate cucinavi cucini
        cuciniamo cucinò cura curammo curano curarono curaste curasti curate curava curavamo curavano curavate curavi
        curi curiamo curò diploma diplomammo diplomano diplomarono diplomaste diplomasti diplomate diplomava
        diplomavamo diplomavano diplomavate diplomavi diplomi diplomiamo diplomò diresse dirige dirigeva dirigi
        dirigiamo dirigono diventa ebbe ebbero entra era erano eravamo eravate eri fine fini finiamo finimmo finirono
        finisce finisci finiscono finiste finisti finite finiva finivamo finivano finivate finivi finono finì forma
        formammo formano formarono formaste formasti formate formava formavamo formavano formavate formavi formi
        formiamo formò foste fosti frequenta frequentammo frequentano frequentarono frequentaste frequentasti
        frequentate frequentava frequentavamo frequentavano frequentavate frequentavi frequenti frequentiamo frequentò
        fu fummo furono geste gesti gestiamo gestimmo gestirono gestisce gestisci gestiscono gestiste gestisti gestite
        gestiva gestivamo gestivano gestivate gestivi gestono gestì ha hai hanno inizia iniziammo iniziano iniziarono
        iniziaste iniziasti iniziate iniziava iniziavamo iniziavano iniziavate iniziavi inizii iniziiamo iniziò
        insegna insegnammo insegnano insegnarono insegnaste insegnasti insegnate insegnava insegnavamo insegnavano
        insegnavate insegnavi insegni insegniamo insegnò introduce istrue istrui istruiamo istruimmo istruirono
        istruisce istruisci istruiscono istruiste istruisti istruite istruiva istruivamo istruivano istruivate
        istruivi istruono istruì lascia lasciammo lasciano lasciarono lasciaste lasciasti lasciate lasciava lasciavamo
        lasciavano lasciavate lasciavi lascii lasciiamo lasciò lavora lavorammo lavorano lavorarono lavoraste
        lavorasti lavorate lavorava lavoravamo lavoravano lavoravate lavoravi lavori lavoriamo lavorò mantenne
        mantiene migliora migliorammo migliorano migliorarono miglioraste migliorasti migliorate migliorava
        miglioravamo miglioravano miglioravate miglioravi migliori miglioriamo migliorò mostra mostrammo mostrano
        mostrarono mostraste mostrasti mostrate mostrava mostravamo mostravano mostravate mostravi mostri mostriamo
        mostrò occupa occupammo occupano occuparono occupaste occupasti occupate occupava occupavamo occupavano
        occupavate occupavi occupi occupiamo occupò organizza organizzammo organizzano organizzarono organizzaste
        organizzasti organizzate organizzava organizzavamo organizzavano organizzavate organizzavi organizzi
        organizziamo organizzò ottenne ottiene parla parlammo parlano parlarono parlaste parlasti parlate parlava
        parlavamo parlavano parlavate parlavi parli parliamo parlò parte partecipa partecipammo partecipano
        parteciparono partecipaste partecipasti partecipate partecipava partecipavamo partecipavano partecipavate
        partecipavi partecipi partecipiamo partecipò parti partiamo partimmo partirono partiste partisti partite
        partiva partivamo partivano partivate partivi partono partì pianifica pianificammo pianificano pianificarono
        pianificaste pianificasti pianificate pianificava pianificavamo pianificavano pianificavate pianificavi
        pianifici pianificiamo pianificò prende prendemmo prenderono prendeste prendesti prendete prendette
        prendettero prendeva prendevamo prendevano prendevate prendevi prendi prendiamo prendono prepara preparammo
        preparano prepararono preparaste preparasti preparate preparava preparavamo preparavano preparavate preparavi
        prepari prepariamo preparò presenta presentammo presentano presentarono presentaste presentasti presentate
        presentava presentavamo presentavano presentavate presentavi presenti presentiamo presentò progetta
        progettammo progettano progettarono progettaste progettasti progettate progettava progettavamo progettavano
        progettavate progettavi progetti progettiamo progettò realizza realizzammo realizzano realizzarono realizzaste
        realizzasti realizzate realizzava realizzavamo realizzavano realizzavate realizzavi realizzi realizziamo
        realizzò riceve ricevemmo riceverono riceveste ricevesti ricevete ricevette ricevettero riceveva ricevevamo
        ricevevano ricevevate ricevevi ricevi riceviamo ricevono ricopre ricopriva riduce riorganizza riorganizzammo
        riorganizzano riorganizzarono riorganizzaste riorganizzasti riorganizzate riorganizzava riorganizzavamo
        riorganizzavano riorganizzavate riorganizzavi riorganizzi riorganizziamo riorganizzò risponde rispondemmo
        risponderono rispondeste rispondesti rispondete rispondette rispondettero rispondeva rispondevamo rispondevano
        rispondevate rispondevi rispondi rispondiamo rispondono segue segui seguiamo seguimmo seguirono seguiste
        seguisti seguite seguiva seguivamo seguivano seguivate seguivi seguono seguì sei serve servi serviamo servimmo
        servirono serviste servisti servite serviva servivamo servivano servivate servivi servono servì siamo siete
        sostitue sostitui sostituiamo sostituimmo sostituirono sostituisce sostituisci sostituiscono sostituiste
        sostituisti sostituite sostituiva sostituivamo sostituivano sostituivate sostituivi sostituono sostituì studia
        studiammo studiano studiarono studiaste studiasti studiate studiava studiavamo studiavano studiavate studiavi
        studii studiiamo studiò supervisiona supervisionammo supervisionano supervisionarono supervisionaste
        supervisionasti supervisionate supervisionava supervisionavamo supervisionavano supervisionavate
        supervisionavi supervisioni supervisioniamo supervisionò sviluppa sviluppammo sviluppano svilupparono
        sviluppaste sviluppasti sviluppate sviluppava sviluppavamo sviluppavano sviluppavate sviluppavi sviluppi
        sviluppiamo sviluppò svolge svolgeva termina terminammo terminano terminarono terminaste terminasti terminate
        terminava terminavamo terminavano terminavate terminavi termini terminiamo terminò torna trasforma
        trasformammo trasformano trasformarono trasformaste trasformasti trasformate trasformava trasformavamo
        trasformavano trasformavate trasformavi trasformi trasformiamo trasformò usa usammo usano usarono usaste
        usasti usate usava usavamo usavano usavate usavi usi usiamo usò vende vendemmo venderono vendeste vendesti
        vendete vendette vendettero vendeva vendevamo vendevano vendevate vendevi vendi vendiamo vendono verifica
        verificammo verificano verificarono verificaste verificasti verificate verificava verificavamo verificavano
        verificavate verificavi verifici verificiamo verificò viene vive vivemmo viverono viveste vivesti vivete
        vivette vivettero viveva vivevamo vivevano vivevate vivevi vivi viviamo vivono è
        """,
        /// The forms of a verb that a noun can be the subject of, as written with accents, in the languages that drop the pronoun.
        thirdPersons: """
        aiuta aiutano aiutarono aiutava aiutavano aiutò amministra amministrano amministrarono amministrava
        amministravano amministrò analizza analizzano analizzarono analizzava analizzavano analizzò assicura
        assicurano assicurarono assicurava assicuravano assicurò assume assumeva assumono assunse aumenta aumentano
        aumentarono aumentava aumentavano aumentò aveva avevano collabora collaborano collaborarono collaborava
        collaboravano collaborò comincia cominciano cominciarono cominciava cominciavano cominciò completa completano
        completarono completava completavano completò consegue contribue contribuirono contribuisce contribuiscono
        contribuiva contribuivano contribuono contribuì controlla controllano controllarono controllava controllavano
        controllò coordina coordinano coordinarono coordinava coordinavano coordinò costrue costruirono costruisce
        costruiscono costruiva costruivano costruono costruì crea creano crearono creava creavano cresce crescerono
        crescette crescettero cresceva crescevano crescono creò cucina cucinano cucinarono cucinava cucinavano cucinò
        cura curano curarono curava curavano curò diploma diplomano diplomarono diplomava diplomavano diplomò diresse
        dirige dirigeva dirigono diventa ebbe ebbero entra era erano fine finirono finisce finiscono finiva finivano
        finono finì forma formano formarono formava formavano formò frequenta frequentano frequentarono frequentava
        frequentavano frequentò fu furono geste gestirono gestisce gestiscono gestiva gestivano gestono gestì ha hanno
        inizia iniziano iniziarono iniziava iniziavano iniziò insegna insegnano insegnarono insegnava insegnavano
        insegnò introduce istrue istruirono istruisce istruiscono istruiva istruivano istruono istruì lascia lasciano
        lasciarono lasciava lasciavano lasciò lavora lavorano lavorarono lavorava lavoravano lavorò mantenne mantiene
        migliora migliorano migliorarono migliorava miglioravano migliorò mostra mostrano mostrarono mostrava
        mostravano mostrò occupa occupano occuparono occupava occupavano occupò organizza organizzano organizzarono
        organizzava organizzavano organizzò ottenne ottiene parla parlano parlarono parlava parlavano parlò parte
        partecipa partecipano parteciparono partecipava partecipavano partecipò partirono partiva partivano partono
        partì pianifica pianificano pianificarono pianificava pianificavano pianificò prende prenderono prendette
        prendettero prendeva prendevano prendono prepara preparano prepararono preparava preparavano preparò presenta
        presentano presentarono presentava presentavano presentò progetta progettano progettarono progettava
        progettavano progettò realizza realizzano realizzarono realizzava realizzavano realizzò riceve riceverono
        ricevette ricevettero riceveva ricevevano ricevono ricopre ricopriva riduce riorganizza riorganizzano
        riorganizzarono riorganizzava riorganizzavano riorganizzò risponde risponderono rispondette rispondettero
        rispondeva rispondevano rispondono segue seguirono seguiva seguivano seguono seguì serve servirono serviva
        servivano servono servì sono sostitue sostituirono sostituisce sostituiscono sostituiva sostituivano
        sostituono sostituì studia studiano studiarono studiava studiavano studiò supervisiona supervisionano
        supervisionarono supervisionava supervisionavano supervisionò sviluppa sviluppano svilupparono sviluppava
        sviluppavano sviluppò svolge svolgeva termina terminano terminarono terminava terminavano terminò torna
        trasforma trasformano trasformarono trasformava trasformavano trasformò usa usano usarono usava usavano usò
        vende venderono vendette vendettero vendeva vendevano vendono verifica verificano verificarono verificava
        verificavano verificò viene vive viverono vivette vivettero viveva vivevano vivono è
        """,
        /// Everyday verbs in the third person, as written with accents: no CV verbs, but the ones a noun before them is the subject of.
        everydayVerbs: """
        abita abitano abitarono abitava abitavano abitò adora adorano adorarono adorava adoravano adorò ama amano
        amarono amava amavano amò andarono andava andavano andò apprezza apprezzano apprezzarono apprezzava
        apprezzavano apprezzò ascolta ascoltano ascoltarono ascoltava ascoltavano ascoltò balla ballano ballarono
        ballava ballavano ballò beve beveva bevevano bevono bevve bevvero cammina camminano camminarono camminava
        camminavano camminò canta cantano cantarono cantava cantavano cantò capiscisce capisciscono cerca cercano
        cercarono cercava cercavano cercò chiede chiederono chiedette chiedeva chiedevano chiedono colleziona
        collezionano collezionarono collezionava collezionavano collezionò compra comprano comprarono comprava
        compravano comprò conobbe conobbero conosce conoscerono conoscette conosceva conoscevano conoscono corre
        correrono corrette correva correvano corrono corse corsero crede crederono credette credeva credevano credono
        danno dava davano dice diceva dicevano dicono diede diedero dipinge dipingeva dipingevano dipingono dipinse
        dipinsero disse dissero domina dominano dominarono dominava dominavano dominò dorme dormirono dormiva
        dormivano dormono dormì esce escono faceva facevano fanno fece fecero gioca giocano giocarono giocava
        giocavano giocò guida guidano guidarono guidava guidavano guidò lesse lessero manga mangano mangarono mangava
        mangavano mangò nuota nuotano nuotarono nuotava nuotavano nuotò odia odiano odiarono odiava odiavano odiò
        padroneggia padroneggiano padroneggiarono padroneggiava padroneggiavano padroneggiò parla parlano parlarono
        parlava parlavano parlò pedala pedalano pedalarono pedalava pedalavano pedalò piacciono piace piaceva
        piacevano piacque piacquero possedeva possedevano possiede possiedono pratica praticano praticarono praticava
        praticavano praticò preferiscisce preferisciscono resta restano restarono restava restavano restò rimane
        rimaneva rimanevano rimangono rimase rimasero risiede risiederono risiedette risiedeva risiedevano risiedono
        sanno sapeva sapevano sceglie sceglieva sceglievano scelgono scelse scelsero scrisse scrissero scrive
        scriverono scrivette scriveva scrivevano scrivono sente sentirono sentiva sentivano sentono sentì seppe
        seppero sogna sognano sognarono sognava sognavano sognò spera sperano sperarono sperava speravano sperò stanno
        stava stavano stette stettero teneva tenevano tengono tenne tennero tiene trasferiscisce trasferisciscono
        trova trovano trovarono trovava trovavano trovò usa usano usarono usava usavano uscirono usciva uscivano uscì
        usò vanno vede vederono vedette vedeva vedevano vedono vengono veniva venivano venne vennero viaggia viaggiano
        viaggiarono viaggiava viaggiavano viaggiò vide videro viene visse vissero vive viverono vivette viveva
        vivevano vivono
        """,
        /// Words of negation, doubt or degree, wish or intention, future and condition: in no other list.
        modality: """
        sarei saresti sarebbe saremmo sareste sarebbero avrei avresti avrebbe avremmo avreste avrebbero farei faresti farebbe
        faremmo fareste farebbero
        sogno_di lo_sogno intenzione_di
        aiutera aiuterai aiuteranno aiuterebbe aiuterebbero aiuterei aiuteremmo aiuteremo aiutereste aiuteresti
        aiuterete aiutero amministrera amministrerai amministreranno amministrerebbe amministrerebbero amministrerei
        amministreremmo amministreremo amministrereste amministreresti amministrerete amministrero analizzera
        analizzerai analizzeranno analizzerebbe analizzerebbero analizzerei analizzeremmo analizzeremo analizzereste
        analizzeresti analizzerete analizzero appena assicurera assicurerai assicureranno assicurerebbe
        assicurerebbero assicurerei assicureremmo assicureremo assicurereste assicureresti assicurerete assicurero
        aumentera aumenterai aumenteranno aumenterebbe aumenterebbero aumenterei aumenteremmo aumenteremo aumentereste
        aumenteresti aumenterete aumentero avra avranno avremo avrete avro circa collaborera collaborerai
        collaboreranno collaborerebbe collaborerebbero collaborerei collaboreremmo collaboreremo collaborereste
        collaboreresti collaborerete collaborero cominciera comincierai comincieranno comincierebbe comincierebbero
        comincierei comincieremmo comincieremo cominciereste comincieresti comincierete cominciero completera
        completerai completeranno completerebbe completerebbero completerei completeremmo completeremo completereste
        completeresti completerete completero contribuira contribuirai contribuiranno contribuirebbe contribuirebbero
        contribuirei contribuiremmo contribuiremo contribuireste contribuiresti contribuirete contribuiro controllera
        controllerai controlleranno controllerebbe controllerebbero controllerei controlleremmo controlleremo
        controllereste controlleresti controllerete controllero coordinera coordinerai coordineranno coordinerebbe
        coordinerebbero coordinerei coordineremmo coordineremo coordinereste coordineresti coordinerete coordinero
        costruira costruirai costruiranno costruirebbe costruirebbero costruirei costruiremmo costruiremo costruireste
        costruiresti costruirete costruiro creera creerai creeranno creerebbe creerebbero creerei creeremmo creeremo
        creereste creeresti creerete creero crescera crescerai cresceranno crescerebbe crescerebbero crescerei
        cresceremmo cresceremo crescereste cresceresti crescerete crescero cucinera cucinerai cucineranno cucinerebbe
        cucinerebbero cucinerei cucineremmo cucineremo cucinereste cucineresti cucinerete cucinero curera curerai
        cureranno curerebbe curerebbero curerei cureremmo cureremo curereste cureresti curerete curero desidera
        desidero deve devo diplomera diplomerai diplomeranno diplomerebbe diplomerebbero diplomerei diplomeremmo
        diplomeremo diplomereste diplomeresti diplomerete diplomero dovrei fara faro finira finirai finiranno
        finirebbe finirebbero finirei finiremmo finiremo finireste finiresti finirete finiro formera formerai
        formeranno formerebbe formerebbero formerei formeremmo formeremo formereste formeresti formerete formero forse
        frequentera frequenterai frequenteranno frequenterebbe frequenterebbero frequenterei frequenteremmo
        frequenteremo frequentereste frequenteresti frequenterete frequentero gestira gestirai gestiranno gestirebbe
        gestirebbero gestirei gestiremmo gestiremo gestireste gestiresti gestirete gestiro iniziera inizierai
        inizieranno inizierebbe inizierebbero inizierei inizieremmo inizieremo iniziereste inizieresti inizierete
        iniziero insegnera insegnerai insegneranno insegnerebbe insegnerebbero insegnerei insegneremmo insegneremo
        insegnereste insegneresti insegnerete insegnero intende intendo istruira istruirai istruiranno istruirebbe
        istruirebbero istruirei istruiremmo istruiremo istruireste istruiresti istruirete istruiro lasciera lascierai
        lascieranno lascierebbe lascierebbero lascierei lascieremmo lascieremo lasciereste lascieresti lascierete
        lasciero lavorera lavorerai lavoreranno lavorerebbe lavorerebbero lavorerei lavoreremmo lavoreremo lavorereste
        lavoreresti lavorerete lavorero magari mai malapena migliorera migliorerai miglioreranno migliorerebbe
        migliorerebbero migliorerei miglioreremmo miglioreremo migliorereste miglioreresti migliorerete migliorero
        mostrera mostrerai mostreranno mostrerebbe mostrerebbero mostrerei mostreremmo mostreremo mostrereste
        mostreresti mostrerete mostrero ne neanche nemmeno nessuna nessuno niente non nulla occupera occuperai
        occuperanno occuperebbe occuperebbero occuperei occuperemmo occuperemo occupereste occuperesti occuperete
        occupero organizzera organizzerai organizzeranno organizzerebbe organizzerebbero organizzerei organizzeremmo
        organizzeremo organizzereste organizzeresti organizzerete organizzero parlera parlerai parleranno parlerebbe
        parlerebbero parlerei parleremmo parleremo parlereste parleresti parlerete parlero partecipera parteciperai
        parteciperanno parteciperebbe parteciperebbero parteciperei parteciperemmo parteciperemo partecipereste
        parteciperesti parteciperete partecipero partira partirai partiranno partirebbe partirebbero partirei
        partiremmo partiremo partireste partiresti partirete partiro parzialmente piacerebbe pianificera pianificerai
        pianificeranno pianificerebbe pianificerebbero pianificerei pianificeremmo pianificeremo pianificereste
        pianificeresti pianificerete pianificero pochi poco possiamo possibilmente posso possono potrebbe potrei
        prendera prenderai prenderanno prenderebbe prenderebbero prenderei prenderemmo prenderemo prendereste
        prenderesti prenderete prendero preparera preparerai prepareranno preparerebbe preparerebbero preparerei
        prepareremmo prepareremo preparereste prepareresti preparerete preparero presentera presenterai presenteranno
        presenterebbe presenterebbero presenterei presenteremmo presenteremo presentereste presenteresti presenterete
        presentero probabilmente progettera progetterai progetteranno progetterebbe progetterebbero progetterei
        progetteremmo progetteremo progettereste progetteresti progetterete progettero puo purche qualora quasi
        realizzera realizzerai realizzeranno realizzerebbe realizzerebbero realizzerei realizzeremmo realizzeremo
        realizzereste realizzeresti realizzerete realizzero ricevera riceverai riceveranno riceverebbe riceverebbero
        riceverei riceveremmo riceveremo ricevereste riceveresti riceverete ricevero riorganizzera riorganizzerai
        riorganizzeranno riorganizzerebbe riorganizzerebbero riorganizzerei riorganizzeremmo riorganizzeremo
        riorganizzereste riorganizzeresti riorganizzerete riorganizzero rispondera risponderai risponderanno
        risponderebbe risponderebbero risponderei risponderemmo risponderemo rispondereste risponderesti risponderete
        rispondero sara saranno saremo sarete saro se seguira seguirai seguiranno seguirebbe seguirebbero seguirei
        seguiremmo seguiremo seguireste seguiresti seguirete seguiro senza servira servirai serviranno servirebbe
        servirebbero servirei serviremmo serviremo servireste serviresti servirete serviro sostituira sostituirai
        sostituiranno sostituirebbe sostituirebbero sostituirei sostituiremmo sostituiremo sostituireste sostituiresti
        sostituirete sostituiro spera sperare spero stento studiera studierai studieranno studierebbe studierebbero
        studierei studieremmo studieremo studiereste studieresti studierete studiero supervisionera supervisionerai
        supervisioneranno supervisionerebbe supervisionerebbero supervisionerei supervisioneremmo supervisioneremo
        supervisionereste supervisioneresti supervisionerete supervisionero sviluppera svilupperai svilupperanno
        svilupperebbe svilupperebbero svilupperei svilupperemmo svilupperemo sviluppereste svilupperesti svilupperete
        sviluppero terminera terminerai termineranno terminerebbe terminerebbero terminerei termineremmo termineremo
        terminereste termineresti terminerete terminero trasformera trasformerai trasformeranno trasformerebbe
        trasformerebbero trasformerei trasformeremmo trasformeremo trasformereste trasformeresti trasformerete
        trasformero usera userai useranno userebbe userebbero userei useremmo useremo usereste useresti userete usero
        vendera venderai venderanno venderebbe venderebbero venderei venderemmo venderemo vendereste venderesti
        venderete vendero verificera verificerai verificeranno verificerebbe verificerebbero verificerei verificeremmo
        verificeremo verificereste verificeresti verificerete verificero vivera viverai viveranno viverebbe
        viverebbero viverei viveremmo viveremo vivereste viveresti viverete vivero vogliamo voglio vogliono voleva
        volevi volevo vorrebbe vorrei vorresti vuoi vuole
        """
    )
}
