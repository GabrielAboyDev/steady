/* Steady — the live keyboard on the landing page.
 *
 * This is a faithful port of the real engine's maths, not a mock-up:
 *   - next-letter weights are the aggregate frequency of every word that can
 *     still follow the prefix (PredictiveEngine.nextLetterWeights)
 *   - scales come from KeyLayout.keyScales, with the same sqrt normalisation,
 *     the same min/max range and the same blend toward neutral
 *   - the tiers, the three strength profiles and the 1 + (scale - 1) * 0.5
 *     height curve match Shared/Theme.swift and Shared/DynamicKeyboardView.swift
 *
 * The word list is the top 6,000 words of the same OpenSubtitles frequency list
 * the app's dictionary is compiled from (profanity removed), ranked; the app
 * itself carries ~47,000 words and ~80,000 next-word pairs. Word weights here
 * are Zipfian by rank, which is close enough to the real counts that the
 * keyboard behaves the same.
 *
 * Data: the word list is derived from FrequencyWords by hermitdave
 * (https://github.com/hermitdave/FrequencyWords), built from the OpenSubtitles
 * 2018 corpus and licensed CC-BY-SA 4.0 — so that list, as embedded below, is
 * CC-BY-SA 4.0 too. The next-word pairs come from count_2w.txt in Peter
 * Norvig's n-gram collection (https://norvig.com/ngrams/), from the Google Web
 * Trillion Word Corpus. See docs/support.html#credits.
 */
(function () {
  "use strict";

  var WORDS = "you i the to a it and that of is in what we me this he for my on have your do was no not be are don know can with but all so just there here they like get she go if right out about up at him now oh one come well her how yeah will got want think as see did good who why from let his yes when going time an okay back look us would them where were take then had or been our gonna tell really man some say hey could didn by need something has too more way down make very never only people over because little please love should mean said sorry give off am thank any two even much doing sure thing these help first into anything still find life nothing sir day god work their uh again maybe must before other wait stop call after won talk away than thought home night put great those last better everything told new things always keep long years leave does money around doesn name place ever feel guys father guy made old isn which big lot done hello nice believe girl someone fine thanks wanted kind coming house every ok through being course stay left dad enough happened came may mother wrong world bad might three today listen another understand hear remember ask own same show else talking found next getting care car looking son try woman went hi dead many mind wasn friend best mom morning trying boy together yourself job saw family real without baby room wouldn already move most seen live miss actually huh both heard once ready head called used idea knew hold happy door such brother also pretty bit took haven yet men whole start use while since wife days guess tomorrow matter meet bring tonight everyone run wanna hard ah alone myself school gone um end saying phone play looks couldn problem few friends gotta ago open anyone hope face until lost police excuse turn business case wants says true die heart soon each worry later year watch music hand having probably beautiful doctor sit eat thinking young second working water person part kids late stuff exactly under death minute pay crazy forget everybody kid change gave happen five drink far knows its whatever eyes shut aren hit taking easy times check hands minutes deal different means point inside makes asked somebody mine making body afraid sleep chance dear quite four anyway close ain party fun against word comes important set shall story number daughter least waiting hurt wish moment fight week husband girls rest married fire game nobody mr children side stand read though cut started sister supposed between child goes hours speak women behind almost truth blood able lady anymore playing gets shot reason trouble break war city walk town trust met office question brought yours welcome high wow couple half died cool free either seems power whoa bye buy telling honey tried front team answer gun boys line send news stupid bed hurry full months save sometimes become along hate food outside light needs dog country clear order em fact lord captain six hot funny black alive pick feeling living cause ahead lose king plan dinner sighs sort leaving shouldn running boss alright promise taken safe ma book sent white hour anybody small perfect lives special parents john himself perhaps sounds serious sick company ha scared uncle poor red past earth possible shoot touch sound top laughs cannot asking win glad control hmm human drive hair jack luck happens air ten daddy finally chuckles fast cold seem laughing words hospital street hang dance meeting till others catch follow sense lie evening master known dream write million voice sweet rather felt sign lucky somewhere bet jesus longer calling worked quiet looked less pull beat careful coffee return secret weeks weren date seeing fall given ooh fault straight takes song future gentlemen loved changed road calm wonderful mad turned drop ladies learn step absolutely early explain clean piece yesterday throw picture land feet wonder questions speaking worth darling dude giving president eye quick moving figure state strong sam none amazing ones works act needed weird law worried report goodbye missing choice happening chief wedding strange general pain kidding decided ya pass tired class officer kept wake worse busy eh mistake kiss court building finish during age ship caught marry meant sell dark watching system suppose evidence movie ride completely mouth totally birthday tv forgive born imagine information instead definitely security certainly film month lying unless train seven wear clothes michael hotel christmas attack hasn round expect sing terrible george bag history blue near broke station seriously forever david frank except thinks message entire joe table talked across rock lovely handle middle buddy paid protect using floor ran swear spend situation ring anywhere dangerous bill york army lead bought finished fair sun letter fool attention club simple interesting space test box group single sitting marriage join fear peace forgot force short normal charlie present enjoy mike crime horse ground american count area charge honor lunch miles radio idiot ball surprise paper key boat quickly gold bar fish mark tom wearing crying accident government eight fell cover certain interested deep star sea agree problems detective prison major stick offer difficult smart personal record stopped hide whether bank trip relax america public list afternoon brain fix proud tea service screaming forward angry park soul fighting peter rich agent blow paul dress mary missed scene standing saved mm respect killer ice mess tough feels church sad cell drunk share camera within card fly ben girlfriend laugh smell broken mum honest often starting calls spent third english visit mama judge window hungry dare relationship moved prove private wall seat position lieutenant realize lt especially machine walking art pleasure bloody college french involved cry became lived impossible obviously neither accept boyfriend besides queen teacher cops sake loves carry teach apartment upset green la liked cute evil professor contact joke cop huge holy store jail likes lawyer doubt continue appreciate cat shop driving congratulations wrote village quit field james wine decision south sleeping slow laughter island glass beginning cash dying hundred whose difference plane push continues mmm singing eating north mrs tree madam gift truck putting bear board grab beer stuck magic support rules grunts partner reach wind colonel max immediately seconds thousand gives experience cheers victim upon computer christ planet promised bus henry dirty search staying dreams arrest holding suddenly usually lots shoes er jump rid yo knock owe harry grow worst river aunt patient kitchen aah fat passed final summer bob listening escape everywhere moon arms turns address ow match gasps grand yep shh nervous de choose themselves decide mate drinking press bother foot hadn blame drugs type rings mission named heaven picked paris race risk books further danny action allowed orders learned price arrived nick otherwise pictures fit smoke favor played notice awesome smile director guard begin spot surprised innocent narrator herself london feelings enemy battle ourselves alex dollars allow nine gay department guilty apart earlier duty jim suit bell west legs hero destroy stage bunch according chicken bigger grunting low helping admit closed names witness upstairs arm steal jimmy kick twice cross ways sergeant indeed gas keeping energy pregnant waste helped fired favorite tony taste locked places writing adam brothers starts prince form sold silly mention build throat hole figured track ringing lock leg above hiding steve seemed breakfast engine written complete video applause however pressure fresh weapon sky stole study burn reading crowd treat roll double spirit danger cost empty level memory itself acting interest nose plans following bathroom built closer ray sarah band groans apparently excited richard losing animals flight nature raise pop client bomb neck suspect warm extra bottle van heavy mommy dogs wild ridiculous simply lee animal showed billy shooting keeps camp guns medical shame hoping whom bird majesty flowers famous asleep beauty driver keys rain awful large local deserve stone jane grace consider weekend wondering lay plenty willing pants sweetheart skin excellent beach faith beg responsible military cheering opportunity common bottom german whoever cook walked papers justice hall commander drug main knife devil necessary although princess lights flying rose knowing clearly hat agreed johnny corner code note tommy due correct apologize language stars faster cars folks fellow several grandma shows leader leaves restaurant east shouting blind ghost cup gotten tight conversation tells lies nor pulled hanging speed stories health advice held beyond rule hardly possibly inspector cousin trial emergency ought eddie somehow hearing states account spoke file understood angel tape milk powerful weapons practice manager pardon vote jake national career minister super taught robert biggest plays natural dancing copy plus martin cake freedom among breath operation chris crew challenge market meat towards bringing dropped student lied strength size breathe color monster loud photo aw nearly sight greatest games bridge dressed arrested horrible coach planning checked breaking noticed fantastic screams serve ideas investigation center older pack soldiers nonsense doc project training example trick prepared science united travel incredible grandpa paying character teeth criminal charles chinese truly honestly bro survive bobby target feed nurse fake records breathing sweetie numbers oil belong whoo perfectly amy forgotten remain original papa onto concerned credit ugh invited discuss research easier view chair hurts strike roger fill condition mountain dr nowhere sheriff kim turning brown recognize heads audience jealous pretend society finding shirt comfortable meaning guest pieces dry letting began aye jeff female release ho cards pray unfortunately destroyed ended universe prepare opinion movies soldier wash program heat usual ticket stolen prefer aware surely male base matters lift lab command proof cream selling believed create afford sunday total dumb threw france birth created realized british noise nuts students birds social brilliant bodies tie opened ours bucks kevin mister ugly ryan focus dan opens exist followed england draw purpose letters daniel opening bullet anna lately stayed falling season ends suggest joy distance responsibility whenever issue thousands process sword shower weak lonely happiness eric tiny desk pool property forced settle indistinct weight received gang bite friday disappeared interview expecting kinda surgery horses mayor babe ancient handsome thomas saturday staff lines unit fan gentleman introduce fate split recently expected add ordered slowly alarm member slept signed enter spanish garden brings brave pig model finger medicine access failed flat easily discovered based screw insane cares weather fingers san scott path soft harm style community sees basically al signal nope spare speech covered shake loose snow russian lake bright roof ohh sending paint remind pal post sugar heading streets damage silence doors pete ed success wet nah amount members kate manage safety returned harder fbi block showing fancy chef contract dig chest drinks dave buried brian trade journey stomach changes details thoughts divorce funeral maria football reality theory gosh ruined gate william spread outta japanese sudden coat sooner cheese larry spring page ears simon castle hidden storm cos personally artist hill exciting permission jerry expensive tickets forest barely eggs goin regret lesson lover bread andy subject legal growing ill jason mood owner caused beeping points dating loss secretary revenge santa likely rent connection assistant reasons yelling painting trees doctors rush foreign rough murderer century nights pair runs pocket farm matt bike obvious ate grew professional tim goodness parts alan university square grandfather europe genius cases ruin winter tongue memories da buying cancer clock ocean dna liar tour thief bleep lisa rights including competition smith planned emily boring victims mentioned bones plant bless warning knocking re crash bedroom lower silver groaning madame defense results toilet event complicated shape priest royal cheap romantic downstairs invite fortune tears avoid reached higher familiar telephone burning filled kelly alice airport jobs grown walter rachel giant insurance woods scare pleased period political player stops secrets laura repeat photos finds statement suck younger china humans delicious particular proper rome belongs attacked bath hired site knowledge led guests celebrate map horn eventually pity powers ashamed assume glasses rise fixed request officers pounds data carefully per depends jury waited positive attorney direction families doin forces location walls useless grant saving speaks fought meal deliver answers changing temple scary millions offered regular carrying official jacket switch grave chase role odd faces becomes closes badly tall confused affair television shock raised panting pizza image clears golden patients watched committed suffer arthur wherever plate appear chocolate clever hm mercy shots lucy dealing trap charges phil bang poison butt drove yourselves headed babies yellow soup mystery picking sat wound traffic courage hunt indian rat terms italian emma checking disease managed winner council appointment monday crack threat jenny physical nation source chose healthy carl victory rick stood kicked annie disgusting palace below shopping neighborhood march lips midnight advantage pure india aside mail dawn effect spell freak wood enemies gary awake chuckling vacation violence leo grandmother modern luke firm prime heh touched talent piano license cooking honour concern moves available factory gods value central union mirror studio media taxi dies iron hearts desire rob claire fred songs washington monkey pride pills miracle swim burned smells joking christian bleeding hook beating protection treatment ear carter metal disappear grateful extremely treasure rescue capable passing chatter result suffering sisters governor guards louis text literally remove becoming performance stronger rate deeply scream desert vehicle illegal pulling throwing josh unbelievable ted zero dean curious sean candy bone tied edge load susan ahh mountains boom former holiday riding scoffs hundreds sue bags stealing appears arrive remains decent issues tip fail bride penny claim friendship desperate flower dramatic refuse solve theme loving properly dragon mostly chuck directly surface false cast junior hunting silent thou egg germany punch africa woke intelligence borrow winning falls popular escaped witch convinced warn announcer champagne dust kyle someday fallen stranger presence tear internet monsieur therefore technology tires toast wise clark americans notes smoking hank ls april wolf precious rooms coast treated material released uniform hated considered rice exchange steps blake convince beast cow files signs drag cab hung carried ordinary successful eve mistakes houses chattering brains japan creature fourth separate cleaning california lf ll shift elizabeth chicago exact karen goal expert served direct score row marks twenty receive series section pilot jackson darkness thy sale destiny cure spoken armed rare helen grade juice wide tower solution schedule explosion wheel cigarette julie fruit blew victor talks sacrifice range button reports prisoner pie effort youth pot eaten taylor knees garage parking ambulance staring chances circumstances sin gordon progress unusual county stairs campaign vision reporter equipment moments joey mass alien trapped helps route defend trace nasty tests magazine rocks dump rude searching clue connected amen pushed merry zone senior closing freeze emperor incident snake mexico lily actor newspaper sentence greg leading friendly jones chosen engaged julia charming mustn anger spending learning spy sharp shadow warrant elevator kingdom ricky jamie squad shoulder wave amanda highness kinds fishing sometime attitude sucks negative screen workers bored cameras similar understanding beeps chain bull gasping fully robin collect gorgeous morgan passion writer empire international curse hire puts leads id blows sons estate customers maggie gunshot device troops hug design movement thunder object loser pen sobbing politics despite alcohol climb clients conference provide marty seek witnesses earn trash valley fashion howard episode prize previously sports wanting debt wishes hitler wire thee circle approach stock facts remembered percent normally tail joined education bravo library wings growling thrown tank exhales authority current failure nightmare hitting glory knocked studying barry agency apple border rope duck reputation confidence yard beloved lack actual skills films mental salt flesh anne secure highly federal sand emotional setting nothin senator services robbery hates fed reward theater johnson commit patrick entirely extraordinary ships opposite parties stands terry chat events mummy bay slip disappointed settled begins andrew alert detail pink fellas accepted background garbage panic minds belt blowing hollywood agreement jackie pushing ability tiger whispering culture saint jesse task solid doll intend district pa gee custody ignore naturally useful attempt abandoned cutting kissed guarantee barking gather policy violent maid embarrassing childhood wasting bow chick sara disaster revolution online demon heavily coincidence perform thin terrific mac crown identity virgin impressive windows potential guitar committee dozen delivery advance quietly stan teaching hunter latest hurting swing capital counting drew dirt whistle marie hits doug deny urgent threatened behavior molly mixed stays assure subtitles explanation wins unique chasing billion duke production slave agents carol lets cruel mask sally behave bury massive pathetic species approaching jo loan struggle dish trusted jumped firing channel abby stopping asks jean swimming daily basement linda quarter erm bound navy article guide accused transfer guts quality fella roman greater couch cheer vegas shoe title shy punishment los clicks closet fever coward flash impressed bruce siren prisoners sides bowl katie supply sensitive hopefully rolling roy dollar tone voices cheating confess demand museum unknown drama suspicious adult todd frightened warned steady kills crossed lou particularly sandwich laws joint bullets package trained thursday boots possibility albert civil june germans baseball express miserable tuesday parker lion joseph refused shine assault hong jokes breaks argue trail option recall mighty collection oliver wilson accent believes decisions embarrassed mobile customer terribly sec charity considering donna protecting flag kidnapped italy balance creatures nuclear wallet shout vincent entered impression angela jay degrees favour reaction network jessica version concert gear singer diamond defeat steven lane blast wounded anytime partners ages charlotte ceremony league bars orange specific conditions plastic crisis fifth term self offering bud suffered reported commissioner rip mysterious entrance messed tunnel designed neighbor aboard sweat justin ghosts crimes costs deserves dreaming bust el teddy kong messages enjoying afterwards comfort mason surrender gym kitty crush yup arranged suits pee stress cave wing jordan arrange comrade noble tricks betty launch legend mix golf imagination fox kissing butter tax gross edward texas insist marcus classic selfish skull frankie shown bat survived print champion bills therapy lifetime throughout nathan toward sauce experiment margaret describe ross grass cheat attend homework lewis betrayed servant cap tyler bible practically catherine steel wipe burns generation cabin financial industry bond sheep scientists beaten heck deck fans script brand degree painful coughing religion cats stephen influence fuel drawing rabbit exercise attractive touching virus realise torture blessed plain rebecca recent barbara footsteps sacred removed pretending wasted jewish goodnight robot crystal confirm lad mile division scratch reminds walks ending russia contest valuable distant dumped motion electricity centre murders tina jeremy seal standard ellen wore surrounded struck inform gentle status purse prints players charged begging delivered kenny buck nina construction confirmed confession trigger cells frankly ali exit response cancel argument principal turkey lucas clinic greetings neighbors vice toy hannah everyday generous gain idiots holly enjoyed jungle link underground smiling mistress teams product beef whispers religious presents identify chip chffffff surveillance carlos vampire routine uses michelle underneath systems temperature waves tribe brad deputy sophie headquarters equal phones ken reckon related incredibly chill spit tracks oscar makeup bug sounded spirits nerve divorced stake port doorbell worries nephew miller units proceed landing traitor outfit chloe bail fields patience recording foolish loaded tokyo davis costume wayne injured somethin ian pet cage digging spain seats awkward cleaned pattern filthy visiting jews answering concentrate someplace citizens aim nancy affairs thick sport basic electric pleasant cliff nail russell environment western average ease interrupt judy satisfied beep starving documents anniversary beth election warrior forth fetch banks placed timing stones complex frozen replace prayer skip angeles guilt tune woo actions conscience officially martha machines smaller determined blown hail unhappy booth pour berlin cleared packed wrap randy behalf reasonable trunk homes festival tradition cigarettes le beside harvey motive beings bishop dealer defendant backup wounds ouch ann nearby drank effects jonathan dennis benefit adventure territory ve apology dylan unlike owns boxes thus clay developed busted pipe gray goods favourite salad loyal atmosphere eva freaking dropping strangers mouse downtown francisco heroes pit rotten paradise meantime jess organization hills exam fairy earl comment activity frame knight testing habit shelter flow jennifer holes prevent anthony lend cooper figures boston sample strip landed buzzing monk slightly produce annoying judgment laundry ron lousy souls existence belly tries foster returning answered ward plants actress chairman individual hopes tattoo fence sink punk confident yay mistaken limit bothering st uncomfortable wednesday gifts policeman na precisely lawyers greek merely criminals underwear hoped earned reveal appeared derek heavens personality batman virginia wives colour worker pope instructions intelligent worrying vince comin cried traveling bells impact robbed relief host footage odds patrol circus mud captured lessons occasion sets pulse ad invented diamonds matthew auntie cloud francis angels hers classes signature complain blah monitor options claims flies pat britain hid wailing listened countries vic yell rats wondered smooth resist companies fantasy passport pitch hammer homicide casey holds flew jacob noon helicopter dishes spin charm slap apply fools screeching discover previous kit authorities moaning photograph sales fifty mickey beneath farewell clouds slipped represent deaf facing offense citizen clown snap messing hood twelve interests cheated liz informed humanity producer technically accounts extreme gettin cia ii pays profile oxygen jeez gene shed minor ex theatre scientific lovers chaos rocket math stubborn august oi chips intense grey talkin terrorist angle invitation gus gambling respond thirty procedure absolute investigate tragedy stable session capture marrying ripped attacks stretch bush dates unable gates mars artists increase tastes cared bottles highest whirring meanwhile nate grabbed pigs chop olivia wheels shocked reverend commercial escort engagement corpse louise worthy scale beats williams threatening exists academy acts hop judges furniture shared ralph consequences engineer schools softly bombs caroline shark transport population succeed creepy sneak studies destruction keith protected monsters joining punished lightning malcolm shell fascinating chamber ethan romance instance jumping groups exhausted testify studied walker pin imagined drill investigating ye experienced elena necklace loyalty junk cole cries stanley rita southern blocks emotions begun maya liver serving matches surgeon granted jazz july supplies deeper typical kicking obey dancer remote daughters moron latin teachers toby sandy dragged strategy parent jin album compared rubbish helpful powder sync bum passes joan fort choices alley supper alibi sammy pole coke scientist fighter highway blade alpha diet liquor jet widow liberty philip moral carrie award grief thirsty ashley random suspects intention julian active tools driven trauma headache safely alexander knee lads novel conversations waters lookin invisible internal peaceful humming washed drives talented li aid elephant troubles core serial painted divine jam goat opera thieves guessing objection whiskey florida resistance dressing attached aaron brief punish eternal lois required victoria fabulous twins characters cooked ln ruth dreamed arts naughty stabbed tend diane tap soap locker development images global string bitter sharing corn craig fits tent forms votes harold propose monica constantly granny nicely nerves arguing abuse relatives survival gloves tracking zoe bend review connect separated elder beard admiral diana salary areas disturb pro maintain solved wealth possession sang gimme plates shoulders burnt recorded upper counts tale profit colleague warehouse hostage shore miami fifteen visitors bo net insult owen cities causing lemon heal banging honeymoon appeal marshall critical creating scotland crane enormous testimony praise fights indians commission growls nicole sins fraud branch happily bout covering occurred beans raw muscle pages tense relationships management assignment blonde catching exposed canada dont han von comedy marco stroke whistling buildings shaking facility appropriate remarkable transferred drawn clicking symbol motor employees ambassador mothers pile feeding soda checks bears cookies awfully stepped toys levels differently magnificent steak tube leaders superior herr pan expression currently throne deadly bee tooth depressed potatoes wicked resources native centuries karl poetry multiple cable shortly buzz socks fingerprints goddess chin anxious september colors basketball promises explained appearance musical sends slide aii shawn ultimate pork communication payment structure paperwork obsessed lazy russians actors squeeze magical colleagues admire madness roads entry injury burden racing manner freezing bits norman mount battery dessert pound visited motel rumbling cinema fond halfway rifle reception statue fridge brick abandon lap natalie wars recommend brush nelson pill concept delay quarters korea janet rub mall soil complaint sail baker coughs bucket description badge measure hip function indistinctly harris foundation labor willie waiter homeless proved unfortunate log meetings giggles combat poem polish handed mia weed raymond tons satellite jersey eagle privacy chapter treating wisdom flip entering barn farmer clan budget pub temporary effective sonny wendy juan lamb plot riley proposal sticks searched blessing rage bothered sydney basis manners recover twist neil leak item catholic sighing retired kings inner cents affect forbidden patch drops necessarily provided meters booked returns gloria fires humor torn rocky introduced creative betray soviet various added discovery cowboy suspected suggested delighted sticking dive shane radar prosecutor amber vast quinn owned cookie finest felix pump valentine counter sorts coin warren slaves marine illness sack bid require moscow largest washing achieve causes mo dope nest palm logan constant boo medication gravity booze noah evan abroad christine rising analysis cuts eats employee vodka damaged solar height pops yards terrified suitcase chemical preparing advanced fund wears chirping web phase prom suggesting fleet lame irish editor october assumed whip mel region amongst temper discussion engines operate sunshine acted undercover horror tested smash contrary roses poker wrapped korean graham mi fu ivan focused liam tragic carla demons rounds entertainment gathered uhh yells lincoln crossing blanket nut travis pockets limited paintings sober caesar sis intended niece computers tennis needle chicks traditional delicate independent leslie lauren grandson repair brandon executive colin recognized holmes regarding weakness aliens gunshots european method tool demands permit towel daisy nowadays spider northern rangers zoo praying antonio passengers con australia technique cellphone gently operations planes bunny gunfire shining backwards skill baron kidnapping iike marshal petty sealed massage raising menu diary wagon audition mitch mexican casino bacon diego dutch promotion click forgiveness burst permanent interfere chanting spencer recovered registered sunny packing scenes superman questioning unfair admitted ancestors polite completed swallow conduct prayers sheet fried avenue poisoned reverse newspapers ford complaining senses investment absurd potato understands grows inspired ruby celebrating tag ram requires bonnie bugs leonard elliot hooked jill ranch safer worn crashing lands heather ash leather grounds assuming nails dana conspiracy thanksgiving pierre guardian rumors yen megan ashes terror misunderstanding tire boats parade halt immunity adults steam kang closely pearl soccer adrian priority shouts donald happier khan struggling root larger november boot conflict laughed debbie cherry honking concerns celebration sore unconscious cattle breasts fairly fee recognise wade radiation holidays raining forgetting lungs register shadows specifically sarge ideal turtle spoil deserved ronnie gina candidate lance types bloke explode immediate belonged identified di hunger closest combination nanny seth gabriel develop detectives severe en organized franklin gut splendid dismissed pm yang halloween ellie vulnerable continued vital comrades bureau drawer harper retreat carson benny pillow troy ace cart nap chan ham announce borrowed parked galaxy voted muffled sebastian jewelry kisses luggage groom oops lighter masters alliance buddies clothing denied drown alike excellency relative photographs burger dough alicia wreck approve produced christina physically stations eli samantha spiritual sire roaring stab inch servants limits unexpected arrival whimpering basket sheets scandal stink homer tara christopher toes shield shooter instant objects rehearsal disturbing directed scan electronic republic overnight counsel sirens dorothy bait dignity explains lean heroin tracy rex barney gossip humble economy worlds impress clara tissue threaten et bump supreme bingo mitchell excitement mankind document broad vietnam vessel lit dale killers connor mario foul stare deaths hut elements coma laying coffin paula cocaine puppy louder handled announcement oath mob cotton deposit taxes injuries jen autopsy advise gig lecture posted skinny lo include revealed infected relieved assistance solo determine terrorists elsewhere lamp practical marked adorable rubber purple operating suite apologies personnel beam poet samples arrow counselor carpet allen audrey spotted floating corrected located journalist insisted operator rely singh fooled arrives leon walt eastern ay shave remaining toss anderson lip acid nora si december anonymous inn planted oldest breast sixth error reporting egypt islands jules roommate sings scum visitor giggling described geez inches commitment hercules react cows protest misery theft embrace darn harsh andrea communicate fathers faithful hector flame medal silk photographer trevor cemetery rear freddy banana allison emotion chap dated excuses bin jew gum crushed efforts content corporal realised del rap hopeless debate era luckily ton liquid swell peggy feast murphy attracted application profession bench vanessa ahem symptoms scout crashed keen aircraft formed hon aggressive pale significant duncan clubs visual embassy defence cabinet display fame gibbs drowned wolves filming dunno cursed twin sorrow vault defeated watson quote penalty bargain pepper speaker compare satan helmet scar copies fuss envelope perry stinks african arrangements wished honored believing discussed assigned rosa oven jenna attacking tin sonic collar mere romeo belief storage rusty psycho climbing melissa fears sum dedicated ladder alternative raid dining ms corporate folk jon replaced bailey un heels duties smarter existed surprising chess requested cruise primary rhythm drum models motorcycle adopted barrel cargo planets shove wha surprises rosie dings trailer cannon tables ally lawrence wee tapes dull sandra teenage kent cooperate risks dug worthless arriving kindness ties items grip relations rumor skirt frog paige lloyd claimed perfume instrumental flames association loses january spike israel eleven gallery ginger activities iraq boarding fist stuffed improve creation connie infection strikes wiped tension whistles kindly certificate curtis bold threats claudia sid twisted suspended affected envy whale dial cameron martial controlled lung coal upside imperial pam paranoid signing congress villa candles filling becky comic faint recovery volunteer tech bleed positions cindy narrow forbid stuart perspective faced neat pierce observe cycle psychic handling goose accidentally conclusion designer sits importance spots francs sweep destroying communist blackmail pacific risky glorious filed hatred cam deals pos fooling persons scotch executed brakes blank tender kurt turner tub sucker slight addition campus ritual prey graduate anyways ew fry genuine ned judging doubts warden ceiling practicing somewhat established attempted zombie generations gathering warriors mick electrical collins sobs couples depend institute miranda principle fixing therapist compete compliment worship residence democracy joel published myth helpless screwing kennedy execution appetite formal strictly sucked tanks chickens gwen technical stella rod meets shepherd brazil brutal alison vain switched chi deer brooklyn dresses retire overcome inspiration benjamin nicky thrilled tae suggestion dummy sailor destination bass picnic idol trucks rank denise yu veronica blocked strict hiya formula clerk samurai disturbed vera cafe wandering consciousness val nikki min bare hans caleb butcher arrangement chased ministry brandy sweater locate apologise parole examine trains candle prior stream passage reaching organ directions asses outer proves morris luxury pistol losers funds sunset strings fortunately gotcha tomb freddie engineering element balloon ty broadcast spray ninja eternity handy crawl slice nations behaviour pace stiff lick concrete allah vegetables euros sausage constable spinning rolls genetic loudly marvelous subway creep scheme performed plug rejected brenda respected backs protocol muscles kidney finishing products im wu invasion affection woody endless discipline horns absence waking dudes philosophy cracked nicholas reed verdict drake connections privilege anyhow scent naive daylight controls airplane values jolly swore blaring consent puzzle disagree argh winds vanished wizard ranger celebrity sniffles stores aha intentions plague farmers breeze rascal convenient bonus dong hush instinct entitled porter maurice wrist originally coins drain physics phoebe furious sniffs vampires defending sector income finn offended decides laser fled beers boxing accurate kung snakes thumb bald sharon suspicion convicted roots shares bernard jessie wang harrison blues confusing lobby recipe las winston generally seeking secretly declare freaked missile ensure tricky pointed hockey bubble contacts maximum reminded carriage curtain clues hostages circles author wallace receiving debts cellar tortured tips mates mortal reporters associate honesty laptop jung katherine rainbow seed mature deed kay expenses discussing pirate meals performing remained prostitute adams retirement platform claus erica beds writes illusion mill dealt hears tryin manhattan mole rang prosecution fatal copper troubled heir traces owners length dentist zach lesbian enterprise tournament travelling confessed roast website ja mikey flood harbor lola rory richie mansion mademoiselle auction desires bachelor haunted distracted smashed rodney scheduled negotiate champ allows shotgun cocktail donkey pointing butler dizzy methods reference georgia bully lydia collapse alfred ana minimum chairs hee patty owes included carmen civilization prices wealthy bart depression tide rented bra lin fellows rot password th kirk pedro spill cured naomi hardest deceased sleepy static hawaii almighty murray offers bruno phrase disgrace sources approval turtles screech snack collected ding fur jewels jan cheek legally ditch benefits roars arnold dime domestic chuckle hack ransom chang bore muslim loads waitress nurses glenn spite rebel clearing andre fortunate survivors reply disappoint orbit expose gin austin toe sympathy intel growth psychiatrist slams encounter daphne passenger monkeys accompany hats column sigh pounding economic tales theirs brat follows spreading burt hilarious hallway hamilton exclusive chimes greet decades bowling buttons confusion thud hooker ruining dreadful collecting lions sheila douglas february elvis forty sleeps sung brass shrink zack whimpers sworn email proven tasty covers sandwiches rarely wyatt programme irene dee contacted chemistry assured applied elected subjects lust label shakespeare tan ego forgiven phoenix companion lottery worm publicity butterfly dialogue cal tremendous pervert establish dearest intimate eager se cathy atlantic contains thompson shirley bets inhales presentation allergic den wells spoiled chen accomplished repay politicians logic gratitude afghanistan exception ultimately pablo compromise majority journal signals bent dock meg essential campbell climate experiments ink magazines rivers teresa administration passionate precise lawn via jeans murmuring resort announced buddha fries capacity lena opponent chains minus caitlyn apples angie seattle aww instrument healing convention messenger explore sonia versus survivor ruled boyd clarence madison cough experts disguise archer bicycle noises inviting pregnancy declared yi vicky drums wooden innocence mouths bees creaking cloth sasha unh skies painter allies miguel pond runway robbie assist lana presented mona sickness civilian fighters facebook customs florence remembers sharks juliet shrimp tore seventh ou avoiding dawson isaac rolled championship household float chad ballet cracking raj possessed harmless curiosity vicious officials glove nearest manny begged que withdraw shocking guessed nightmares greedy forehead corps pirates rudy reservation hunters fog flu hint peanut stark gamble erin autumn bracelet contain arrogant simpson piper knocks sperm gesture materials lindsay alexis ticking standards ribs receipt regards whatsoever homeland leap targets snoring damon leaf jar brooke proposed savage caring ivy approximately kidnap carries bounce creek pony cleaner businessman lunatic unlikely gal situations colony sells choi chambers volume sweets panties respects reads seeds engage explosives stewart violet mutual lighting scores lenny savings beware stephanie educated complaints cassie doomed offensive harvest qualified relaxed cape buffalo triple fireworks palmer armor poverty leadership rode ambition cakes trousers bean melt racist bam ankle occupied nicer correctly terrifying hugh gasp villain willy marc draft factor whew countess portrait suggests font blair learnt pencil coordinates collapsed reserve jeffrey shirts umbrella stevie ta traveled auto logical chew eliminate beverly carbon cancelled crawling stepping independence medium canceled tess fanny seated upbeat asian drowning messy quest represents fletcher memorial doyle stressed bearing watches spoon cooperation tucker earthquake sailing involve houston asia spectacular reliable breach sophisticated echo indicate swamp vehicles manual elegant compound serves scares rattling pursue dreamt stefan revolutionary wa rig convincing fiona tribal cleveland lex depth blaming aids elaine wakes occur camping fart stamp kathy assassin approved crucial annual torch dallas fulfill bon resting reunion witnessed graduated sub howling clyde hospitals stall legacy otto riot shops whereabouts teenager samuel squealing mines danced crowded orleans literature morgue strongest agnes transmission panel sole sequence sexually georgie hugo denny smack congratulate anxiety choking tolerate mode communications welfare dice orphan locks settlement advertising uniforms mcgee devoted shoots principles circuit nickname dot elderman scenario choir stunt smoked isolated equally statements gil shaw lipstick courtesy hobby hesitate hatch luis sylvia phoned experiences popped quid fragile husbands fiction persuade pastor dolls pose ji ming rupees tricked ruins sadly owed importantly louie industrial musician labour evolution salute ba cent bartender calendar hal miracles balcony regard valerie fold organs nigel theo einstein boris suitable inaudible melody phillip movements differences barbecue trading strongly fluid scholarship translation cricket shuttle moans quicker picks murderers videos initial perimeter questioned yea cousins divided linked laboratory crab pulls landlord reggie hostile classified cultural measures update cottage backyard amateur chopper rash despair honorable shiny hawk shorts ni representative wong pouring distress tanner telegram pimp dip trophy marilyn hallelujah neal es howdy misses flush magician dynamite cuba conquer unpleasant jealousy regrets lifted increased toxic broadway sakes pudding rally needing bloom corporation buys disorder interrupting sadness needn cease barnes scoundrel sensible evans specialist dragging bribe burke bothers interrogation prescription referring knives graduation liking bubbles grid haircut regardless lodge poisoning feathers edgar software marina sophia queens oak trips scaring avery awhile sofa conscious swords instincts".split(" ");
  var BIGRAMS = Object.create(null);
  "you:can,are,have|i:have,am,was|the:same,first,following|to:the,be,a|a:new,few,lot|it:is,was,to|and:the,a,other|that:the,is,you|of:the,a,this|is:a,the,not|in:the,a,this|what:is,you,the|we:have,are,can|me:to,a,and|this:is,page,site|he:was,is,had|for:the,a,this|my:products,own,life|on:the,a,this|have:been,a,to|your:own,item,password|do:not,you,it|was:a,not,the|no:longer,one,more|not:be,have,a|be:a,used,the|are:not,the,a|don:and|know:that,what,how|can:be,not,also|with:the,a,an|but:it,the,not|all:rights,the,of|so:that,much,you|just:a,as,the|there:is,are,was|here:to,for,is|they:are,were,have|like:to,a,the|get:a,the,help|she:was,is,had|go:to,back,down|if:you,the,it|right:to,now,of|out:of,the,to|about:the,this,it|up:to,the,for|at:the,least,a|him:to,and,in|now:items,is,and|oh:well,yeah,my|one:of,or,to|come:to,from,up|well:as,known,in|her:to,own,husband|how:to,the,do|yeah:i,yeah,it|will:be,not,have|got:it,a,to|want:to,it,a|think:that,it,of|as:a,the,well|see:all,the,more|did:not,you,the|good:for,to,and|who:are,have,is|why:the,do,are|from:the,a,your|let:me,us,you|his:own,wife,or|yes:checking,or,yes|when:the,you,it|going:to,on,through|time:to,of,and|an:online,item,important|okay:to,with,for|back:to,in,and|look:at,for,like|us:to,at,a|would:be,like,have|them:to,in,and|where:the,you,they|were:not,the,in|take:a,the,place|then:the,you,it|had:a,been,to|or:the,a,more|been:a,in,made|our:site,own,staff|gonna:be,get,do|tell:you,a,me|really:good,do,is|man:who,and,in|some:of,time,other|say:that,it,the|hey:guys,there,hey|could:be,not,have|by:the,a,this|need:to,for,a|something:that,to,like|has:been,pictures,a|too:much,many,long|more:than,information,about|way:to,of,that|down:the,to,and|make:a,the,it|very:good,much,well|never:been,be,had|only:a,one,the|people:who,in,to|over:the,a,to|because:of,it,the|little:bit,more,or|please:contact,note,read|love:to,the,you|should:be,not,have|mean:that,to,the|said:that,the,he|sorry:for,to,about|give:you,the,a|off:the,to,of|am:not,a,to|thank:you,the,all|any:other,of,time|two:years,of,or|even:if,though,more|much:more,of,as|doing:so,it,the|sure:to,that,you|thing:that,to,is|these:are,changes,two|help:you,pages,department|first:time,to,and|into:the,a,account|anything:else,to,in|still:have,be,in|find:a,the,out|life:and,of,in|nothing:to,but,more|day:of,and,to|god:is,and,has|work:with,in,on|their:own,lives,children|uh:oh,huh|again:with,and,in|maybe:it,you,a|must:be,have,not|before:the,you,they|other:than,items,hand|wait:for,to,until|stop:the,and,at|call:the,for,to|after:the,a,all|won:the,a,by|talk:about,to,with|away:from,with,the|than:the,a,one|thought:that,it,of|home:page,and,to|night:and,in,of|put:the,it,in|great:deal,deals,for|those:who,of,that|last:year,week,post|better:than,to,and|everything:you,from,is|told:me,the,him|new:window,and,york|things:that,to,are|always:been,be,a|keep:the,it,your|long:as,time,term|years:of,ago,old|leave:the,a,it|does:not,it,the|money:from,to,order|around:the,and,a|name:of,and,is|place:to,in,of|ever:seen,been,since|feel:free,like,that|guys:are,in,who|father:and,of,was|guy:who,in,is|made:by,to,a|old:and,man,woman|which:is,the,are|big:black,breasts,deal|lot:of,more,to|done:in,by,to|hello:all,to,everyone|nice:to,and,if|believe:that,in,it|girl:in,who,and|someone:who,else,to|fine:art,and,for|thanks:for,to,again|wanted:to,a,the|kind:of,and,to|coming:to,from,soon|house:of,and,in|every:day,time,effort|ok:to,for,with|through:the,a,our|being:a,the,used|course:of,is,in|stay:informed,in,at|left:to,the,in|dad:and,was,is|enough:to,for,of|happened:to,in,on|came:to,from,out|may:be,not,have|mother:and,of,was|wrong:with,and,to|world:of,and,is|bad:credit,for,news|might:be,have,not|three:years,months,times|today:and,to,announced|listen:to,and,for|another:window,one,person|understand:the,that,what|hear:the,from,about|remember:me,that,the|ask:for,a,the|own:the,personal,online|same:time,as,way|show:that,only,the|else:can,if,is|talking:about,to,with|found:in,that,the|next:message,to,by|getting:a,the,to|care:of,and,for|car:insurance,hire,and|looking:for,at,to|son:of,and,is|try:to,and,it|woman:who,in,and|went:to,on,into|hi:all,there,everyone|dead:in,and,or|many:of,people,other|mind:that,and,is|friend:of,about,and|best:of,to,in|mom:and,son,is|morning:and,of,to|trying:to,out,not|boy:gay,and,who|together:with,to,in|yourself:to,and,in|job:of,in,and|saw:the,a,that|family:and,of,members|real:estate,time,world|without:the,a,any|baby:is,shower,and|room:for,and,with|already:a,been,have|move:to,the,on|most:of,important,popular|seen:in,as,the|live:in,with,on|miss:the,you,out|actually:a,be,have|both:the,of,in|heard:of,the,that|once:again,you,a|ready:to,for,and|head:of,and,to|called:the,a,for|used:to,in,for|idea:of,that,to|knew:that,it,the|hold:em,the,a|happy:to,with,and|door:to,and,of|such:as,a,that|brother:and,of,sister|also:be,the,a|pretty:much,good,sure|bit:of,more,about|took:the,a,place|haven:for,of,and|yet:to,been,another|men:and,in,who|whole:or,thing,of|start:time,of,to|use:of,the,a|while:the,you,we|since:the,it,they|wife:and,of,is|days:of,ago,after|guess:that,it,the|tomorrow:and,morning,night|matter:of,what,how|meet:the,with,your|bring:the,you,a|tonight:and,at,to|everyone:else,who,is|run:the,by,a|wanna:be,know,see|hard:to,drive,work|ah:well,yes|alone:in,and,or|myself:to,and,in|school:of,and,in|gone:to,through,on|um:die|end:of,time,up|saying:that,it,the|phone:number,calls,numbers|play:a,in,the|looks:like,at,to|problem:with,is,of|few:years,days,of|friends:and,of,about|gotta:be,go,get|ago:and,by,in|open:this,to,the|anyone:who,else,know|hope:that,you,to|face:of,and,the|until:the,you,it|lost:in,the,to|police:officers,and,officer|excuse:for,to,me|turn:on,to,your|business:and,days,in|case:of,for,studies|wants:to,a,the|says:that,the,it|true:that,for,to|die:in,for,of|heart:of,disease,and|soon:as,be,to|each:other,of,year|worry:about,that,if|later:than,in,on|year:old,of,and|watch:this,the,it|music:and,is,in|hand:and,in,side|having:a,to,the|probably:the,be,not|beautiful:and,women,woman|doctor:or,of,if|sit:down,in,on|eat:the,and,a|thinking:about,of,that|young:people,girls,man|second:half,time,and|working:with,on,in|water:and,quality,to|person:who,to,in|part:of,in,is|kids:and,to,are|late:in,to,for|stuff:that,and,in|exactly:what,the,as|under:the,this,a|death:of,in,penalty|minute:walk,to,of|pay:for,the,a|crazy:frog,and,about|forget:to,the,your|everybody:else,is,in|kid:in,who,and|change:the,in,your|gave:me,the,a|happen:to,in,if|five:years,minutes,days|drink:and,in,a|far:as,more,from|knows:that,what,how|its:own,first,members|whatever:you,the,it|eyes:and,of,to|shut:down,up,the|hit:the,counter,by|taking:the,a,place|easy:to,and,for|times:are,and,the|check:out,to,the|hands:of,and,on|minutes:of,to,from|deal:with,of,to|different:from,types,ways|means:that,of,the|point:of,in,to|inside:the,this,of|makes:it,the,a|asked:to,for,the|somebody:else,who,to|mine:and,is,in|making:a,the,it|body:of,and,is|afraid:of,to,that|sleep:in,and,with|chance:to,of,that|dear:friend,to,all|quite:a,different,as|four:years,of,times|anyway:and,to,so|close:to,the,of|party:poker,sources,to|fun:and,to,with|against:the,a,him|word:of,for,in|comes:to,from,with|important:to,for,that|set:of,up,to|shall:be,not,have|story:of,is,to|number:of,and,is|daughter:of,and,is|least:one,two,a|waiting:for,to,list|hurt:the,you,me|wish:to,you,list|moment:of,to,in|fight:against,for,the|week:of,and,in|husband:and,of,is|girls:in,and,with|rest:of,and,is|married:to,in,and|fire:and,in,protection|game:is,of,and|nobody:else,is,can|mr:and|children:and,in,of|side:of,effects,by|stand:up,for,in|read:more,the,our|though:the,it,they|cut:off,the,and|started:to,within,with|sister:and,of,site|supposed:to,that|between:the,a,two|child:care,is,and|goes:to,on,into|hours:of,ago,a|speak:to,of,with|women:and,in,who|behind:the,a,it|almost:all,every,a|truth:is,of,about|blood:pressure,and,flow|able:to,and,in|lady:of,in,who|anymore:and,because,than|playing:with,the,a|gets:a,the,to|shot:of,at,in|reason:for,to,why|trouble:with,finding,in|break:the,down,in|war:on,in,and|city:of,and,in|walk:to,in,away|town:of,and,in|trust:and,in,me|met:with,the,in|office:of,and,in|question:of,is,about|brought:to,up,in|yours:here,now,to|welcome:to,your,back|high:school,quality,level|couple:of,minutes,years|half:of,the,a|died:in,on,of|cool:and,to,stuff|free:to,online,gay|either:the,a,of|seems:to,that,like|power:of,to,and|bye:to,bye|buy:it,and,a|telling:me,the,you|honey:and|tried:to,it,the|front:of,and,page|team:of,to,and|answer:to,is,the|gun:and,control,in|boys:and,in,are|line:of,with,and|send:a,to,private|news:and,by,from|stupid:and,to,question|bed:and,with,in|hurry:to,up,and|full:of,description,text|months:ago,of,after|save:on,to,up|sometimes:it,the,called|become:a,an,the|along:with,the,a|hate:to,the,it|food:and,is,for|outside:the,of,and|light:of,and,on|needs:to,of,and|dog:and,is,to|country:and,to,in|clear:that,and,recent|order:to,of,for|em:poker,up,online|fact:that,is,of|lord:of,and,is|captain:of,and,in|six:months,years,weeks|hot:and,water,tub|funny:and,thing,to|black:and,jack,gay|alive:and,in,with|pick:up,a,the|feeling:of,that,the|living:in,room,with|cause:of,the,a|ahead:of,and,with|lose:weight,the,their|king:of,and,size|plan:to,for,and|dinner:and,at,with|sort:by,of,order|leaving:the,a,it|running:on,the,a|boss:and,is,of|promise:to,of,that|taken:to,from,in|safe:and,to,for|book:of,is,must|sent:to,by,a|white:paper,and,gold|hour:of,and,or|anybody:else,who,know|small:business,and,number|perfect:for,gift,match|lives:in,of,and|special:offers,pages,needs|parents:and,of,to|john:and,the,is|himself:to,in,and|perhaps:the,a,you|sounds:like,of,and|serious:about,and,problem|sick:of,and,leave|company:is,that,and|ha:ha,of|scared:of,to,and|uncle:and|poor:and,credit,people|red:and,wine,light|past:the,year,few|earth:and,is,to|possible:to,for,that|shoot:the,a,at|touch:with,of,the|sound:of,like,and|top:of,and,quality|laughs:and,at|asking:for,the,price|win:the,a,over|glad:to,you,that|control:of,over,and|human:rights,beings,resources|drive:to,and,the|hair:and,loss,care|jack:black,and,online|luck:with,to,and|happens:to,when,in|air:and,quality,travel|ten:years,minutes,days|finally:got,get,found|fast:and,items,as|cold:and,water,weather|seem:to,like,that|laughing:at,and,so|words:of,and,in|hospital:in,and,of|street:and,in,from|hang:out,on,up|dance:and,music,floor|meeting:of,with,the|till:the,you,they|others:to,in,are|catch:up,the,a|follow:the,up,a|sense:of,to,that|lie:in,to,down|evening:of,and,at|master:of,plan,the|known:as,to,for|dream:of,home,come|write:a,an,to|million:in,other,people|voice:of,and,over|sweet:and,potatoes,potato|rather:than,a,be|felt:that,like,the|sign:in,up,of|lucky:to,enough,and|somewhere:in,else,between|bet:you,on,that|jesus:is,and,was|longer:than,be,available|calling:for,the,card|worked:with,for,in|quiet:and,time,in|looked:at,like,up|less:than,likely,of|pull:the,out,from|beat:the,up,it|careful:to,not,about|coffee:and,shop,table|return:to,policy,an|secret:of,to,that|weeks:ago,of,after|date:of,and,for|seeing:this,the,a|fall:of,in,into|given:to,the,by|fault:of,in,with|straight:to,line,from|takes:a,place,the|song:of,is,and|future:of,generations,and|gentlemen:of|loved:ones,the,one|changed:the,to,from|road:to,and,trip|calm:and,down,the|wonderful:and,to,time|mad:at,cow,and|turned:out,to,off|drop:in,down,the|ladies:and,in,of|learn:more,about,how|step:in,of,is|absolutely:no,free,nothing|early:in,as,on|explain:the,why,how|clean:and,up,the|piece:of,is,in|yesterday:and,that,to|throw:a,the,in|picture:of,to,is|land:and,use,of|feet:of,and,in|wonder:if,what,why|questions:about,or,and|speaking:of,to,countries|worth:the,of,it|giving:the,a,you|president:of,and,for|eye:on,and,of|quick:and,to,access|moving:to,the,in|figure:out,of,in|state:of,and,or|strong:and,enough,in|sam:and,is|none:of,other,yet|amazing:how,and,to|ones:that,who,are|works:with,in,of|act:of,as,and|needed:to,for,in|weird:and,for,to|law:and,of,to".split("|").forEach(function (entry) {
    var i = entry.indexOf(":");
    BIGRAMS[entry.slice(0, i)] = entry.slice(i + 1).split(",");
  });

  var LETTERS = "abcdefghijklmnopqrstuvwxyz".split("");
  var ROWS = ["qwertyuiop", "asdfghjkl", "zxcvbnm"];

  // Mirrors PredictionController.resizeConfig.
  var PROFILES = {
    off: { aggressiveness: 0, hide: false, min: 1, max: 1 },
    medium: { aggressiveness: 0.5, hide: true, min: 0.5, max: 1.35 },
    aggressive: { aggressiveness: 0.9, hide: true, min: 0.5, max: 1.9 }
  };

  function weightOf(rank) { return 1 / (rank + 1); }

  // Aggregate frequency of every word continuing through each next letter.
  function nextLetterWeights(prefix) {
    var weights = Object.create(null);
    for (var i = 0; i < WORDS.length; i++) {
      var word = WORDS[i];
      if (word.length <= prefix.length) continue;
      if (prefix && word.lastIndexOf(prefix, 0) !== 0) continue;
      var letter = word.charAt(prefix.length);
      weights[letter] = (weights[letter] || 0) + weightOf(i);
    }
    return weights;
  }

  // Port of KeyLayout.keyScales.
  function keyScales(weights, config) {
    var maxWeight = 0, i, letter;
    for (i = 0; i < LETTERS.length; i++) {
      maxWeight = Math.max(maxWeight, weights[LETTERS[i]] || 0);
    }
    var out = Object.create(null);
    if (maxWeight <= 0) {
      for (i = 0; i < LETTERS.length; i++) {
        out[LETTERS[i]] = { scale: 1, possible: true };
      }
      return out;
    }
    for (i = 0; i < LETTERS.length; i++) {
      letter = LETTERS[i];
      var weight = weights[letter] || 0;
      if (weight <= 0) {
        out[letter] = { scale: config.hide ? 0 : config.min, possible: false };
        continue;
      }
      var normalized = Math.sqrt(weight / maxWeight);
      var target = config.min + normalized * (config.max - config.min);
      out[letter] = {
        scale: (1 - config.aggressiveness) * 1 + config.aggressiveness * target,
        possible: true
      };
    }
    return out;
  }

  // Port of KeyTier.forScale.
  function tierFor(scale, possible, topScale) {
    if (!possible) return "impossible";
    if (scale >= topScale - 0.001 && scale > 1.05) return "most";
    if (scale > 1.2) return "likely";
    if (scale >= 0.95) return "possible";
    return "unlikely";
  }

  function completions(prefix, limit) {
    var out = [];
    for (var i = 0; i < WORDS.length && out.length < limit; i++) {
      if (WORDS[i].lastIndexOf(prefix, 0) === 0) out.push(WORDS[i]);
    }
    return out;
  }

  function nextWords(previous, limit) {
    var hit = BIGRAMS[previous];
    if (hit) return hit.slice(0, limit);
    return WORDS.slice(0, limit);
  }

  // ---------- the demo ----------

  var root = document.getElementById("demo");
  if (!root) return;

  var fieldEl = root.querySelector("[data-field]");
  var chipsEl = root.querySelector("[data-chips]");
  var trayEl = root.querySelector("[data-tray]");
  var segEl = root.querySelector("[data-seg]");
  var playBtn = root.querySelector("[data-play]");

  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var state = { text: "", profile: "aggressive" };
  var keyEls = Object.create(null);
  var timer = null;
  var autoplayed = false;

  function build() {
    ROWS.forEach(function (row, index) {
      var rowEl = document.createElement("div");
      rowEl.className = "krow" + (index === 1 ? " indent" : "");
      row.split("").forEach(function (letter) {
        var key = document.createElement("button");
        key.type = "button";
        key.className = "key";
        key.tabIndex = -1;
        key.textContent = letter;
        key.setAttribute("aria-label", letter);
        key.addEventListener("click", function () {
          stopAutoplay();
          type(letter);
        });
        keyEls[letter] = key;
        rowEl.appendChild(key);
      });
      trayEl.appendChild(rowEl);
    });

    var bottom = document.createElement("div");
    bottom.className = "krow bottom";
    bottom.appendChild(deco("123"));
    bottom.appendChild(deco("\u{1F310}"));
    bottom.appendChild(action("space", "space", "Space", function () { type(" "); }));
    bottom.appendChild(action("util", "⌫", "Delete", backspace));
    trayEl.appendChild(bottom);
  }

  function deco(label) {
    var el = document.createElement("span");
    el.className = "key deco";
    el.setAttribute("aria-hidden", "true");
    el.textContent = label;
    return el;
  }

  function action(extraClass, label, aria, handler) {
    var el = document.createElement("button");
    el.type = "button";
    el.className = "key " + extraClass;
    el.tabIndex = -1;
    el.textContent = label;
    el.setAttribute("aria-label", aria);
    el.addEventListener("click", function () {
      stopAutoplay();
      handler();
    });
    return el;
  }

  function trailingPrefix(text) {
    var match = /[a-z]+$/.exec(text.toLowerCase());
    return match ? match[0] : "";
  }

  function lastCompletedWord(text) {
    var match = /([a-z]+)[^a-z]+$/.exec(text.toLowerCase());
    return match ? match[1] : "";
  }

  function type(characters) {
    if (state.text.length > 60) state.text = "";
    state.text += characters;
    render();
  }

  function backspace() {
    state.text = state.text.slice(0, -1);
    render();
  }

  function render() {
    var prefix = trailingPrefix(state.text);
    var config = PROFILES[state.profile];
    var scales = keyScales(nextLetterWeights(prefix), config);

    var topScale = 0;
    LETTERS.forEach(function (letter) {
      if (scales[letter].possible) topScale = Math.max(topScale, scales[letter].scale);
    });
    if (topScale === 0) topScale = 1;

    LETTERS.forEach(function (letter) {
      var key = keyEls[letter];
      var entry = scales[letter];
      if (entry.scale <= 0) {
        key.className = "key hidden";
        key.disabled = true;
        key.setAttribute("aria-hidden", "true");
        return;
      }
      key.disabled = false;
      key.removeAttribute("aria-hidden");
      // Height grows at half the rate of width, as in DynamicKeyboardView.
      var height = Math.min(Math.max(1 + (entry.scale - 1) * 0.5, 0.7), 1.5);
      key.className = "key t-" + tierFor(entry.scale, entry.possible, topScale);
      key.style.flexGrow = entry.scale.toFixed(3);
      key.style.height = "calc(var(--key-base) * " + height.toFixed(3) + ")";
      key.style.fontSize = "clamp(11px, calc(var(--key-base) * " + (height * 0.44).toFixed(3) + "), 27px)";
    });

    renderField(prefix);
    renderChips(prefix);
  }

  function renderField(prefix) {
    fieldEl.textContent = "";
    if (!state.text) {
      var hint = document.createElement("span");
      hint.className = "placeholder";
      hint.textContent = "Start typing…";
      fieldEl.appendChild(hint);
    } else {
      var head = state.text.slice(0, state.text.length - prefix.length);
      fieldEl.appendChild(document.createTextNode(head));
      if (prefix) {
        var strong = document.createElement("span");
        strong.className = "prefix";
        strong.textContent = state.text.slice(state.text.length - prefix.length);
        fieldEl.appendChild(strong);
      }
    }
    var caret = document.createElement("span");
    caret.className = "caret";
    caret.setAttribute("aria-hidden", "true");
    fieldEl.appendChild(caret);
  }

  function renderChips(prefix) {
    var words = prefix
      ? completions(prefix, 3)
      : nextWords(lastCompletedWord(state.text), 3);
    chipsEl.textContent = "";
    for (var i = 0; i < 3; i++) {
      var chip = document.createElement("button");
      chip.type = "button";
      chip.className = "chip";
      var word = words[i];
      if (!word) {
        chip.disabled = true;
        chip.textContent = " ";
        chip.setAttribute("aria-hidden", "true");
      } else {
        chip.textContent = word;
        chip.setAttribute("aria-label", "Insert " + word);
        (function (chosen, length) {
          chip.addEventListener("click", function () {
            stopAutoplay();
            state.text = state.text.slice(0, state.text.length - length) + chosen + " ";
            render();
          });
        })(word, prefix.length);
      }
      chipsEl.appendChild(chip);
    }
  }

  // ---------- controls ----------

  segEl.addEventListener("click", function (event) {
    var button = event.target.closest("button[data-profile]");
    if (!button) return;
    stopAutoplay();
    state.profile = button.dataset.profile;
    Array.prototype.forEach.call(segEl.querySelectorAll("button[data-profile]"), function (b) {
      b.setAttribute("aria-pressed", String(b === button));
    });
    render();
  });

  // Bound to the whole demo so it works whether focus landed on the group,
  // the device, or one of the keys.
  root.addEventListener("keydown", function (event) {
    if (event.metaKey || event.ctrlKey || event.altKey) return;
    if (/^[a-zA-Z]$/.test(event.key)) {
      stopAutoplay();
      type(event.key.toLowerCase());
    } else if (event.key === "Backspace") {
      stopAutoplay();
      backspace();
    } else if (event.key === " " || event.key === "Spacebar") {
      stopAutoplay();
      type(" ");
    } else {
      return;
    }
    event.preventDefault();
  });

  // ---------- autoplay ----------

  // Letters, then a tap on the "waiting" chip — the two ways the keyboard
  // gets you through a word.
  var SCRIPT = "thanks for wait".split("").concat([{ chip: 1 }]);

  function play() {
    stopAutoplay();
    state.text = "";
    render();
    var index = 0;
    playBtn.setAttribute("aria-pressed", "true");
    (function step() {
      if (index >= SCRIPT.length) {
        playBtn.setAttribute("aria-pressed", "false");
        timer = null;
        return;
      }
      var item = SCRIPT[index];
      var pause;
      if (typeof item === "string") {
        type(item);
        pause = item === " " ? 520 : 250;
      } else {
        var chip = chipsEl.children[item.chip];
        if (chip && !chip.disabled) chip.click();
        pause = 900;
      }
      index++;
      timer = window.setTimeout(step, pause);
    })();
  }

  function stopAutoplay() {
    if (timer) {
      window.clearTimeout(timer);
      timer = null;
    }
    playBtn.setAttribute("aria-pressed", "false");
  }

  playBtn.addEventListener("click", function () {
    if (timer) {
      stopAutoplay();
    } else {
      play();
    }
  });

  build();
  render();
  root.removeAttribute("data-loading");

  if (!reduceMotion && "IntersectionObserver" in window) {
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting && !autoplayed && !state.text) {
          autoplayed = true;
          window.setTimeout(play, 650);
        }
      });
    }, { threshold: 0.45 });
    observer.observe(root);
  }
})();
