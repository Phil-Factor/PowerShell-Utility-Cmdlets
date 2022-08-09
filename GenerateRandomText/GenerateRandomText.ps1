<#
  .SYNOPSIS
    Picks out random sentences from JSON data that is formatted as a dictionary of arrays
  
  .DESCRIPTION
    this function takes a powershell object that has several keys representing phrase-banks,each 
    of which has an array that describes all the alternative components of a string and from it,
    it returns a string.
    basically, you give it a list of alternatives in an arreay and it selects one of them. 
    However, if you put in the name of an array as one of the alternatives,rather than 
    a word,it will, if it selects it, treat it as a new reference and will select one of 
    these alternatives.
  
  .PARAMETER AllPhraseBanks
  This is the powershell object with the phrasebanks.
  
  .PARAMETER bank
  The name of the phrase-bank to use
  
  .EXAMPLE
    Get-RandomSentence -AllPhraseBanks $MyPhrasebank -bank 'start'
        
        1..1000 | foreach{
          Get-RandomSentence -AllPhraseBanks ($PhraseLists | convertfrom-Json) -bank 'note'
        }>'MyDirectory\notesAboutBooks.txt'
        
        1..10000 | foreach{
          ConvertTo-TitleCase(
            Get-RandomSentence -AllPhraseBanks ($PhraseLists | convertfrom-Json) -bank 'title')
        }>'Mydirectory\BookTitles.txt'
  
  .NOTES
    This function gets called recursively so imitates the elaborate
    recursion of normal written language and, to a lesser extent, speech.
#>
function Get-RandomSentence
{
  [CmdletBinding()]
  param
  (
    $AllPhraseBanks,#the wordbank object to use
    $bank #the array of phrases within the wordbank to use 
  )
  
  $bankLength = $AllPhraseBanks.$bank.Length
  $return = ''
  $AllPhraseBanks.$bank[(Get-Random -Minimum -0 -Maximum ($bankLength - 1))] -split ' ' |
  foreach {
    if ($_[0] -eq '^')
    {
      $collection = $_.TrimStart('^');
      $endPunctuation = if ($collection.Trim() -match '[^\w]+') { $matches[0] }
      else { '' }
      $collection = $collection.TrimEnd(',.;:<>?/!@#$%&*()-_=+')
      $return += (Get-RandomSentence -AllPhraseBanks $AllPhraseBanks -bank $collection)+ $endPunctuation
    }
    else
    { $return += " $($_)" }
  }
  $return
}

<#
  .SYNOPSIS
    Converts a phrase to Title Case, using current culture
  
  .DESCRIPTION
    Takes a string made up of words and gives it the same UpperCase letters as is conventional 
    with the title of books, chapter headings,  or films.
  
  .PARAMETER TheSentence
    This is the heading, sentence, book title or whatever
  
  .EXAMPLE
        PS C:\> ConvertTo-TitleCase -TheSentence 'to program I am a fish'
  
  .NOTES
    Phil Factor November 2020
#>
function ConvertTo-TitleCase
{
  param
  (
    [string]$TheSentence
  )
  
  $OurTextInfo = (Get-Culture).TextInfo
  $result = '';
  $wordnumber = 1
  $result += $TheSentence -split ' ' | foreach {
    if ($WordNumber++ -eq 1 -or $_ -notin ('of', 'in', 'to', 'for', 'with', 'on', 'at', 'from',
        'by', 'as', 'into', 'like', 'over', 'out', 'and', 'that', 'but', 'or', 'as', 'if',
        'when', 'than', 'so', 'nor', 'like',
        'once', 'now', 'a', 'an', 'the'))
    {
      $OurTextInfo.ToTitleCase($_)
    }
    else
    { $OurTextInfo.ToLower($_) }
    
  }
  $result
}

$HumanitiesTheses=@'
{
"adjective":[
"carnivalesque", "rhetorical","divided","new","neoliberal", "sustainable","socially-responsible",
"multimedia","historical","formalist","gendered","historical","heterotopian", "collective",
"cultural","female","transformative","intersectional","political","queer","critical","social",
"spiritual","visual","Jungian","unwanted","Pre-raphaelite","acquired","gender","surreal",
"the epicentre of", "midlife","emotional","coded","fleeting","ponderous","expressive",
"self-descriptive","theoretical","multi-dimensional","dystopic","fragments of","humanistic",
"interpretive","critical","probablistic","aphoristically constructed","disconnected",
"subtle","ingenious","deep","shrewd","astute","sophistical"
],
"doesSomethingWith":[
"evokes","explores","describes","summarises","deliniates","traces","relates","characterises",
"depicts","focuses on","narrates","educes","draws inspiration from",
"tracks the many influences on","meditates on","reflects on","examines","observes",
"offers","scrutinises"
],
"interaction":[
"relationship","affinity","resonance","narrative ","interaction"
],
"something":[
"the body","experience","archetype","queerness","gifts","tenets","synesthesia","politics",
"subculture","memories","oppression","space","abjection","telesthesia","transnationalism",
"care","Ambivalence","neoliberalism","^adjective identity","transcendence","resistance",
"performance","masochism","spectatorship","play","masculinity","aesthetics","phenomenology",
"Blaxpoitation","plasticity","annihilation","identity","regeneration","Narrative",
"Metaphysics","Normativity","progress","erasure","gender perception","complexity","power",
"exceptionalism","surreality","scrutiny","inequality","auto-ethnography","opacity",
"utopic self-invention","experience", "identity", "intellection","approach to ^noun",
"epistemology","contexts","hermeneutics","the role of shame","the aesthetic of detachment"
],
"somethings":[
"bodies","experiences","archetypes","gifts","tenets","synesthesias","political thoughts",
"subcultures","memories","oppressions","Spaces","Abjections","Telesthesias","Transnationalisms",
"Ambivalences","Neoliberalisms","^adjective Identities","Transcendences","Resistances",
"performances","Masochisms","Spectatorships","Aesthetics","Phenomenologies","Identities",
"Regenerations","Narratives", "Normativities","Erasures","gender perceptions","complexities",
"exceptionalisms","inequalities","utopic self-inventions","experiences", "intellections",
"approaches to ^noun",  "epistemologies","contexts"
],
"and":[
"and its relationship to","in combination with", "in contrast to", "and its intersections with",
"in its paradoxical relationship to","in conjunction with"],
"stuff":[
"particular texts","diary entries","painstaking research","diary musings","sporadic poetry",
"personal letters","early drafts of a memoir","newspaper articles","letters to the newspapers",
"august research"
],
"note":[
"The author ^doesSomethingWith ^something ^and ^something in ^stuff by ^writer, and ^doesSomethingWith ^personal, ^personal ^thought on topics from the mundane to the profound.",
"This ^book ^doesSomethingWith various ^adjective ^somethings and their relation to ^source: and the influence of the ^doingSomethingTo ^noun ^doesSomethingWith the ^something ^terminator.",
"^something is at the intersection of ^something, ^something and ^something. it offers a new approach; not only ^doingSomethingTo the ^noun, but ^doingSomethingTo the ^noun",
"This ^book ^doesSomethingWith the ^interaction between ^something and ^something. ^inspiredby, and by ^meditating, new ^feelings are ^made ^terminator","the ^interaction between ^something ^and ^something in this ^book is ^pretty.  ^inspiredby, new ^feelings which dominate the early chapters ^doesSomethingWith ^something ^terminator.",
"It is ^likely that this will ^remain the most ^positive ^book on the subject, balancing as it does the ^interaction between ^something and ^something. ^inspiredby, it ^doesSomethingWith ^something ^terminator.",
"^tracing influences from ^something, ^something and ^something, the ^book ^doesSomethingWith ^noun through time",
"This ^book provides a ^positive, ^positive introduction to ^adjective ^something ^terminator, with a focus on ^noun., By ^meditating, new ^feelings are ^made ^terminator",
"^doingSomethingTo ^adjective ^something is ^positive, ^positive and ^positive. This ^book ^doesSomethingWith the ^adjective and ^adjective imperatives of ^adjective ^noun.",
"^positive, ^positive and yet ^positive, this ^book is unusual in that it is ^inspiredby. It will make you appreciate ^doingSomethingTo ^something ^terminator"
],
"book":[
"book","book","^positive book","^positive exposition","booklet","republished series of lectures",
"dissertation","^positive compilation","^positive work","volume","^positive monograph","tract",
"thesis","publication","expanded journal article","research paper"
],
"likely":[
"probable","likely","quite possible","debatable","inevitable","a done deal",
"probably just a matter of time","in the balance","to be expected"
],
"tracing":[
"tracing","tracking","following","uncovering","trailing","investigatiing","exploring"
],
"remain":[
"estabilsh itself as","be accepted as","remain","be hailed as","be received by the public as",
"be recommended as","become"
],
"pretty":[
"a source of ^positive insights","a ^positive reference","a ^positive statement",
"demanding but ^positive"
],
"positive":[
"comprehensive","challenging","exciting","discoursive","interesting","stimulating","evocative",
"nostalgic","heartwarming","penetrating","insightful","gripping","unusual","didactic","instructive",
"educative","informative","edifying","enlightening","illuminating","accessible","effective","resonant",
"vibrant"
],
"meditating":[
"^doingSomethingTo the ^something and ^something",
"balancing the intricate issues, especially the ^adjective ^something",
"steering clear of the obvious fallacies in their thinking about ^adjective ^something",
"arguing that it is equal in complexity and power to ^something",
"clearing away the misconceptions about ^something"
],
"inspiredby":[
"with a nod to both ^source and ^source",
"It draws inspiration from influences as diverse as ^source and ^source",
"With influences as diverse as as ^source and ^source",
"at the intersection of ^source, ^source and ^source",
"Drawing from sources such as ^source, ^source and ^source as inspiration",
"Taking ideas from writers as diverse as as ^writer and ^writer"
],
"source":[
"Impressionism","Nihilism","left-bank decedence","Surrealism","Psycholinguistics",
"Post-modermnism","Deconstructionism","Empiricism","Existentialism","the humanities",
"Dialectical materialism","Feminist Philosophy","Deontological Ethics","Critical Realism",
"Christian Humanism","Anarchist schools of thought","Eleatics","Latino philosophy","design",
"the Marburg School","the Oxford Franciscan school","Platonic Epistemology","Process Philosophy",
"Shuddhadvaita","urban planning"
],
"writer":[
"Edward Abbey","JG Ballard","Henry James","Kurt Vonnegut","Evelyn Waugh","Wyndham Lewis",
"T E Lawrence","Timothy Leary","Hugh MacDiarmid","William Faulkner","Gabriel Garcia Marquez",
"Henrik Ibsen","Franz Kafka","Mary Wollstonecraft","Henry David Thoreau","Levi Strauss"
],
"terminator":[
"as a means of ^adjective and ^adjective ^something","representing ^adjective claims to ^something",
"as a site of ^something","as ^something","without a connection","as ^adjective ^something",
"as ^adjective ^something and ^something","as ^adjective mediators","in contemporary society",
"and the gendering of space in the gilded age","as ^adjective justice","as violence",
"in the digital streaming age","in an ^adjective framework","in a global context",
"in new ^adjective media","and the violence of ^something","as a form of erasure",
"and the negotiation of ^something","signifying ^adjective relationships in ^adjective natures",
"as a site of ^adjective contestation","in crisis","as ^adjective devices","through a ^adjective lens",
"through a lens of spatial justice","within the ^adjective tradition of ^something."
],
"title":[
"^doingSomethingTo ^something ^terminator.","^noun ^terminator.",
"^doingSomethingTo ^adjective ^something: The ^adjective ^noun.",
"^doingSomethingTo ^noun",
"^doingSomethingTo the ^adjective ^something"
],
"doingSomethingTo":[
"understanding","intervening in", "engaging with", "interpreting",
"speculating about", "tracing the narrative of","introducing the theory of",
"presenting methods and practices of","offering case practices of","describing changes in",
"reinterpreting","critiquing","reimagining","evoking","exploring","describing","summarising",
"deliniating","tracing","relating","characterising","depicting","methodically restructuring",
"focusing on","narrating","educing","tracking the many influences on","meditating on",
"situating","transforming","disempowering","a reading of","transcending",
"activating","the politics of","representations of","interrogating","erasing","redefining",
"identifying","performing","the legibility of","democratizing","de-centering",
"gender and","debating","signaling","embodying","building","the role of","historicizing",
"repositioning","destabilizing","mapping","eliminating","engaging with"
],
"noun":[
"Genre and Justice","^doingSomethingTo Uncertainty","Identity","^something and ^something of ^something",
"Bodies and Static Worlds","^noun of ^adjective Spaces","^something as resistance,",
"Modes of witnessing","representations of trauma","concept of freedom","multimedia experiences",
"bodies","theory and empirical evidence","ecology of ^something","^adjective Labor Migration",
"^something and ^something","^adjective possibilities","^adjective limitations",
"aesthetic exchange","Immersion","abstraction","Revolutionary Sexuality","politics and power",
"aesthetics","aepresentation","^adjective categories","pluralities","gender","gaze",
"forms of ^something","silences","power structures","dissent","^adjective approach","self",
"queerness","modes of being","ontology","agency","epistemologies","intertextuality",
"Hyper-Extensionality","fields of belonging","hybridization","literary justice","visualisation",
"Interpretation","epistemology","narrative experimentation"
],
"feelings":[
"combinations","tensions","synergies","resonances","harmonies","contradictions","paradoxes",
"superimpositions","amalgamations","syntheses"
],
"personal":["deeply personal", "emotionally wrenching","highly charged","itensely private","dark",
"profound","heartfelt","heartwarming","spiritual","nuanced","reflective","deep","unflinching"],
"thought":["ruminations","meditations","interpositions","insights","perceptions"],
"made":[
"distilled","manufactured","woven","synthesised","uncovered","determined","observed","portrayed"
]
}
'@

$HumanitiesTheses>"$pwd\HumanitiesPublications.json"




<# If you store the JSON in the same directory, you can then generate the two lists very quickly
 by using this, saving the resulting lists in your home documents directory #>

Invoke-Expression "$pwd\Get-RandomSentence.ps1"
$PhraseLists = get-content "$pwd\HumanitiesPublications.json"
1..1000 | foreach{
          Get-RandomSentence -AllPhraseBanks ($PhraseLists | convertfrom-Json) -bank 'note'
        }>"$($env:HOMEDRIVE)$($env:homepath)\documents\notesAboutBooks.txt"
        
1..10000 | foreach{
          ConvertTo-TitleCase(
            Get-RandomSentence -AllPhraseBanks ($PhraseLists | convertfrom-Json) -bank 'title')
        }>"$($env:HOMEDRIVE)$($env:homepath)\documents\BookTitles.txt"

