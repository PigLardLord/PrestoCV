/// The closed vocabulary of French (ADR 0023), written as `DescriptionText.normalized` writes a word: lower case,
/// without accents, an elided article as a word of its own; but for the forms of to be and the auxiliaries, which keep them.
extension Vocabulary {
    static let french = Words(
        /// Articles, prepositions, pronouns, auxiliaries, conjunctions and subordinators.
        function: """
        a ai ainsi alors apres as au aussi autre autres aux avaient avais avait avant avec avez aviez avions avoir
        avons ayant bien c ca car ce ceci cela celle celles celui ces cet cette ceux chaque chez comme contre d dans
        de deja depuis des donc dont du en encore enfin ensuite entre es est et etaient etais etait etant ete etes
        etiez etions etre eu eurent eus eut faire fais faisais faisait faisant faisons fait faites font furent fus fut
        ici j je jusqu l la le les lors lorsqu lorsque m ma mais me meme memes mes moi mon nos notre nous on ont or ou
        par parmi pendant plusieurs pour puis puisqu puisque quand que quelque quelques qui quoi s selon sommes sont
        sous souvent suis sur ta tandis tant te tellement tes toi ton toujours tous tout toute toutes tres tu un une
        vers vos votre vous y
        """,
        /// Verbs of a CV: their inflected forms, the infinitives set apart.
        verbs: """
        accompagnaient accompagnais accompagnait accompagnant accompagne accompagnee accompagnees accompagnent
        accompagnes accompagnez accompagniez accompagnions accompagnons administraient administrais administrait
        administrant administree administrees administrent administres administrez administriez administrions
        administrons aidaient aidais aidait aidant aide aidee aidees aident aides aidez aidiez aidions aidons
        amelioraient ameliorais ameliorait ameliorant amelioree ameliorees ameliorent ameliores ameliorez amelioriez
        ameliorions ameliorons animaient animais animait animant anime animee animees animent animes animez animiez
        animions animons assuraient assurais assurait assurant assuree assurees assurent assures assurez assuriez
        assurions assurons attend attendaient attendais attendait attendant attendent attendez attendiez attendions
        attendons attends attendu attendue attendues attendus charge chargee chargees charges choisi choisie choisies
        choisis choisissaient choisissais choisissait choisissant choisissent choisissez choisissiez choisissions
        choisissons choisit collaboraient collaborais collaborait collaborant collaboree collaborees collaborent
        collabores collaborez collaboriez collaborions collaborons commencaient commencais commencait commencant
        commence commencee commencees commencent commences commencez commenciez commencions commencons contribuaient
        contribuais contribuait contribuant contribue contribuee contribuees contribuent contribues contribuez
        contribuiez contribuions contribuons coordonnaient coordonnais coordonnait coordonnant coordonne coordonnee
        coordonnees coordonnent coordonnes coordonnez coordonniez coordonnions coordonnons creaient creais creait
        creant cree creee creees creent crees creez creiez creions creons cuisinaient cuisinais cuisinait cuisinant
        cuisine cuisinee cuisinees cuisinent cuisines cuisinez cuisiniez cuisinions cuisinons demenagaient demenagais
        demenagait demenagant demenage demenagee demenagees demenagent demenages demenagez demenagiez demenagions
        demenagons developpaient developpais developpait developpant developpe developpee developpees developpent
        developpes developpez developpiez developpions developpons devenais devenait devenu devenue deviens devient
        diplomaient diplomais diplomait diplomant diplome diplomee diplomees diploment diplomes diplomez diplomiez
        diplomions diplomons dirigaient dirigais dirigait dirigant dirige dirigeais dirigeait dirigeant dirigee
        dirigees dirigent dirigeons diriges dirigez dirigiez dirigions dirigons embauchaient embauchais embauchait
        embauchant embauche embauchee embauchees embauchent embauches embauchez embauchiez embauchions embauchons
        encadraient encadrais encadrait encadrant encadree encadrees encadrent encadres encadrez encadriez encadrions
        encadrons enseignaient enseignais enseignait enseignant enseigne enseignee enseignees enseignent enseignes
        enseignez enseigniez enseignions enseignons etabli etablie etablies etablis etablissaient etablissais
        etablissait etablissant etablissent etablissez etablissiez etablissions etablissons etablit etudiaient
        etudiais etudiait etudiant etudie etudiee etudiees etudient etudies etudiez etudiiez etudiions etudions
        exploitaient exploitais exploitait exploitant exploite exploitee exploitees exploitent exploites exploitez
        exploitiez exploitions exploitons fini finie finies finis finissaient finissais finissait finissant finissent
        finissez finissiez finissions finissons finit fondaient fondais fondait fondant fonde fondee fondees fondent
        fondes fondez fondiez fondions fondons formaient formais formait formant forme formee formees forment formes
        formez formiez formions formons geraient gerais gerait gerant gere geree gerees gerent geres gerez geriez
        gerions gerons integraient integrais integrait integrant integree integrees integrent integres integrez
        integriez integrions integrons introduis introduit introduite lancaient lancais lancait lancant lance lancee
        lancees lancent lances lancez lanciez lancions lancons menait mene menee mets mis mise obtenu obtenue obtiens
        obtient occupaient occupais occupait occupant occupe occupee occupees occupent occupes occupez occupiez
        occupions occupons organisaient organisais organisait organisant organise organisee organisees organisent
        organises organisez organisiez organisions organisons parlaient parlais parlait parlant parle parlee parlees
        parlent parles parlez parliez parlions parlons participaient participais participait participant participe
        participee participees participent participes participez participiez participions participons perd perdaient
        perdais perdait perdant perdent perdez perdiez perdions perdons perds perdu perdue perdues perdus planifiaient
        planifiais planifiait planifiant planifie planifiee planifiees planifient planifies planifiez planifiiez
        planifiions planifions prend prends preparaient preparais preparait preparant preparee preparees preparent
        prepares preparez prepariez preparions preparons pris prise quittaient quittais quittait quittant quitte
        quittee quittees quittent quittes quittez quittiez quittions quittons realisaient realisais realisait
        realisant realise realisee realisees realisent realises realisez realisiez realisions realisons recrutaient
        recrutais recrutait recrutant recrute recrutee recrutees recrutent recrutes recrutez recrutiez recrutions
        recrutons reduis reduit reduite rejoignait rejoins rejoint rejointe repond repondaient repondais repondait
        repondant repondent repondez repondiez repondions repondons reponds repondu repondue repondues repondus
        responsable restaient restais restait restant reste restee restees restent restes restez restiez restions
        restons reussi reussie reussies reussis reussissaient reussissais reussissait reussissant reussissent
        reussissez reussissiez reussissions reussissons reussit soignaient soignais soignait soignant soigne soignee
        soignees soignent soignes soignez soigniez soignions soignons supervisaient supervisais supervisait
        supervisant supervise supervisee supervisees supervisent supervises supervisez supervisiez supervisions
        supervisons surveillaient surveillais surveillait surveillant surveille surveillee surveillees surveillent
        surveilles surveillez surveilliez surveillions surveillons tenu tenue terminaient terminais terminait
        terminant termine terminee terminees terminent termines terminez terminiez terminions terminons tiens tient
        travaillaient travaillais travaillait travaillant travaille travaillee travaillees travaillent travailles
        travaillez travailliez travaillions travaillons utilisaient utilisais utilisait utilisant utilise utilisee
        utilisees utilisent utilises utilisez utilisiez utilisions utilisons vend vendaient vendais vendait vendant
        vendent vendez vendiez vendions vendons vends vendu vendue vendues vendus
        """,
        /// The infinitives of the verbs of a CV: no present or past, so they explain nothing and say nothing done.
        infinitives: """
        accompagner administre administrer aider ameliore ameliorer animer assure assurer attendre choisir collabore
        collaborer commencer contribuer coordonner creer cuisiner demenager developper devenir diplomer diriger
        embaucher encadre encadrer enseigner etablir etudier exploiter finir fonder former gerer integre integrer
        introduire lancer mener mettre obtenir occuper organiser parler participer perdre planifier prendre prepare
        preparer quitter realiser recruter reduire rejoindre repondre rester reussir soigner superviser surveiller
        tenir terminer travailler utiliser vendre
        """,
        /// Words of time, period and unit, and the months.
        time: """
        actuel actuelle actuellement an ancien ancienne annee annees ans aout aujourd automne avril decembre decennie
        ete fevrier heure heures hiver hui jadis janvier jour jours juillet juin mai maintenant mars mois novembre
        octobre partiel passe plein precedent precedente present printemps saison semaine semaines septembre temps
        """,
        /// Words of level, and the CEFR codes.
        level: """
        a1 a2 avance avancee b1 b2 bilingue c1 c2 courant courante debutant debutante elementaire expert experte
        intermediaire langue maternelle natif native niveau notions
        """,
        /// Words of studying and graduating.
        studying: """
        academie college cours diplome diplomee doctorat ecole ecoles etude etudes etudiant etudiante examen institut
        licence lycee master primaire secondaire these universite universites
        """,
        /// Prepositions and adverbs of time, and the conjunctions that join them: what a pure time phrase is made of, with years.
        timePhrase: """
        a actuellement apres au aux avant de depuis des en ensuite entre et jusqu maintenant ou partir pendant puis
        """,
        /// Words of graduating: a time phrase that holds one joins an education entry and gives its end date.
        graduating: """
        diplome diplomee diplomees diplomes
        """,
        /// Words that go with them in a graduation phrase.
        graduationFrame: """
        ai j je ma mon obtenu suis
        """,
        /// The present and past of to be, as written with accents: a verb that says something done on its own.
        beForms: """
        es est etaient etais etait etant etes etiez etions furent fus fut sommes sont suis étaient étais était étant
        étiez étions été êtes
        """,
        /// The auxiliaries of the perfect, as written with accents: a verb that says something done when a listed form follows it.
        auxiliaries: """
        a ai as avaient avais avait avez aviez avions avons eu eurent eus eut ont
        """,
        /// The forms of a verb that say another person than I, as written with accents, in the languages that drop the pronoun.
        otherPersons: """

        """,
        /// The forms of a verb that a noun can be the subject of, as written with accents, in the languages that drop the pronoun.
        thirdPersons: """

        """,
        /// Everyday verbs in the third person, as written with accents: no CV verbs, but the ones a noun before them is the subject of.
        everydayVerbs: """
        adoraient adorait adore adorent aimaient aimait aime aiment allaient allait appréciaient appréciait apprécie
        apprécient boit boivent buvaient buvait chantaient chantait chante chantent cherchaient cherchait cherche
        cherchent collectionnaient collectionnait collectionne collectionnent conduisaient conduisait conduisent
        conduit connaissaient connaissait connaissent connaît couraient courait courent court dansaient dansait danse
        dansent disaient disait disent dit dormaient dormait dorment dort détestaient détestait déteste détestent
        espère espèrent espéraient espérait faisaient faisait fait font habitaient habitait habite habitent jouaient
        jouait joue jouent lisaient lisait lisent lit mangaient mangait mange mangent marchaient marchait marche
        marchent maîtrisaient maîtrisait maîtrise maîtrisent nagaient nagait nage nagent parlaient parlait parle
        parlent part partaient partait partent peignaient peignait peignent peint pensaient pensait pense pensent
        portaient portait porte portent possède possèdent possédaient possédait pratiquaient pratiquait pratique
        pratiquent prenaient prenait prend prennent préfère préfèrent préféraient préférait restaient restait reste
        restent résidaient résidait réside résident rêvaient rêvait rêve rêvent sait savaient savait savent sort
        sortaient sortait sortent tenaient tenait tiennent tient trouvaient trouvait trouve trouvent utilisaient
        utilisait utilise utilisent va venaient venait viennent vient vit vivaient vivait vivent voient voit vont
        voyagaient voyagait voyage voyagent voyaient voyait écrit écrivaient écrivait écrivent
        """,
        /// Words of negation, doubt or degree, wish or intention, future and condition: in no other list.
        modality: """
        reve_de reve_d
        accompagnera accompagnerai accompagneraient accompagnerais accompagnerait accompagneras accompagnerez
        accompagneriez accompagnerions accompagnerons accompagneront administrera administrerai administreraient
        administrerais administrerait administreras administrerez administreriez administrerions administrerons
        administreront aidera aiderai aideraient aiderais aiderait aideras aiderez aideriez aiderions aiderons
        aimeraient aimerais aimerait aimeriez aimerions souhaiteraient souhaiterais souhaiterait souhaiteriez souhaiterions
        aideront ameliorera ameliorerai amelioreraient ameliorerais ameliorerait amelioreras ameliorerez amelioreriez
        ameliorerions ameliorerons amelioreront animera animerai animeraient animerais animerait animeras animerez
        animeriez animerions animerons animeront assurera assurerai assureraient assurerais assurerait assureras
        assurerez assureriez assurerions assurerons assureront attendra attendrai attendraient attendrais attendrait
        attendras attendrez attendriez attendrions attendrons attendront aucun aucune aura aurai auras aurez aurons
        auront choisira choisirai choisiraient choisirais choisirait choisiras choisirez choisiriez choisirions
        choisirons choisiront collaborera collaborerai collaboreraient collaborerais collaborerait collaboreras
        collaborerez collaboreriez collaborerions collaborerons collaboreront commencera commencerai commenceraient
        commencerais commencerait commenceras commencerez commenceriez commencerions commencerons commenceront
        contribuera contribuerai contribueraient contribuerais contribuerait contribueras contribuerez contribueriez
        contribuerions contribuerons contribueront coordonnera coordonnerai coordonneraient coordonnerais
        coordonnerait coordonneras coordonnerez coordonneriez coordonnerions coordonnerons coordonneront creera
        creerai creeraient creerais creerait creeras creerez creeriez creerions creerons creeront cuisinera cuisinerai
        cuisineraient cuisinerais cuisinerait cuisineras cuisinerez cuisineriez cuisinerions cuisinerons cuisineront
        demenagera demenagerai demenageraient demenagerais demenagerait demenageras demenagerez demenageriez
        demenagerions demenagerons demenageront desire developpera developperai developperaient developperais
        developperait developperas developperez developperiez developperions developperons developperont devrais
        diplomera diplomerai diplomeraient diplomerais diplomerait diplomeras diplomerez diplomeriez diplomerions
        diplomerons diplomeront dirigera dirigerai dirigeraient dirigerais dirigerait dirigeras dirigerez dirigeriez
        dirigerions dirigerons dirigeront dois doit embauchera embaucherai embaucheraient embaucherais embaucherait
        embaucheras embaucherez embaucheriez embaucherions embaucherons embaucheront encadrera encadrerai
        encadreraient encadrerais encadrerait encadreras encadrerez encadreriez encadrerions encadrerons encadreront
        enseignera enseignerai enseigneraient enseignerais enseignerait enseigneras enseignerez enseigneriez
        enseignerions enseignerons enseigneront environ envisage espere esperons etablira etablirai etabliraient
        etablirais etablirait etabliras etablirez etabliriez etablirions etablirons etabliront etudiera etudierai
        etudieraient etudierais etudierait etudieras etudierez etudieriez etudierions etudierons etudieront exploitera
        exploiterai exploiteraient exploiterais exploiterait exploiteras exploiterez exploiteriez exploiterions
        exploiterons exploiteront finira finirai finiraient finirais finirait finiras finirez finiriez finirions
        finirons finiront fondera fonderai fonderaient fonderais fonderait fonderas fonderez fonderiez fonderions
        fonderons fonderont formera formerai formeraient formerais formerait formeras formerez formeriez formerions
        formerons formeront gerera gererai gereraient gererais gererait gereras gererez gereriez gererions gererons
        gereront guere integrera integrerai integreraient integrerais integrerait integreras integrerez integreriez
        integrerions integrerons integreront jamais lancera lancerai lanceraient lancerais lancerait lanceras lancerez
        lanceriez lancerions lancerons lanceront n ne ni occupera occuperai occuperaient occuperais occuperait
        occuperas occuperez occuperiez occuperions occuperons occuperont organisera organiserai organiseraient
        organiserais organiserait organiseras organiserez organiseriez organiserions organiserons organiseront parlera
        parlerai parleraient parlerais parlerait parleras parlerez parleriez parlerions parlerons parleront
        participera participerai participeraient participerais participerait participeras participerez participeriez
        participerions participerons participeront partiellement pas peine perdra perdrai perdraient perdrais perdrait
        perdras perdrez perdriez perdrions perdrons perdront personne peut peuvent peux planifiera planifierai
        planifieraient planifierais planifierait planifieras planifierez planifieriez planifierions planifierons
        planifieront pourrais pourrait pouvons preparera preparerai prepareraient preparerais preparerait prepareras
        preparerez prepareriez preparerions preparerons prepareront presque pretends prevois probablement quittera
        quitterai quitteraient quitterais quitterait quitteras quitterez quitteriez quitterions quitterons quitteront
        realisera realiserai realiseraient realiserais realiserait realiseras realiserez realiseriez realiserions
        realiserons realiseront recrutera recruterai recruteraient recruterais recruterait recruteras recruterez
        recruteriez recruterions recruterons recruteront repondra repondrai repondraient repondrais repondrait
        repondras repondrez repondriez repondrions repondrons repondront restera resterai resteraient resterais
        resterait resteras resterez resteriez resterions resterons resteront reussira reussirai reussiraient
        reussirais reussirait reussiras reussirez reussiriez reussirions reussirons reussiront rien sans sera serai
        seras serez serons seront si sinon soignera soignerai soigneraient soignerais soignerait soigneras soignerez
        soigneriez soignerions soignerons soigneront souhaite souhaitons supervisera superviserai superviseraient
        superviserais superviserait superviseras superviserez superviseriez superviserions superviserons superviseront
        surveillera surveillerai surveilleraient surveillerais surveillerait surveilleras surveillerez surveilleriez
        surveillerions surveillerons surveilleront terminera terminerai termineraient terminerais terminerait
        termineras terminerez termineriez terminerions terminerons termineront travaillera travaillerai
        travailleraient travaillerais travaillerait travailleras travaillerez travailleriez travaillerions
        travaillerons travailleront utilisera utiliserai utiliseraient utiliserais utiliserait utiliseras utiliserez
        utiliseriez utiliserions utiliserons utiliseront vendra vendrai vendraient vendrais vendrait vendras vendrez
        vendriez vendrions vendrons vendront veulent veut veux voudrais voudrait voulais voulons
        """
    )
}
