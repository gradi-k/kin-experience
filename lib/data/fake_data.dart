import '../models/site.dart';
import '../models/resto.dart';
import '../models/hotel.dart';
import '../models/event.dart';
import '../models/entreprise.dart';

/// Données factices pour permettre à l’application de fonctionner sans
/// connexion réseau ni base de données.  Chaque liste contient quelques
/// éléments d’exemple pour chaque catégorie afin de rendre l’interface
/// agréable au démarrage.  Les coordonnées géographiques, les notes et
/// les descriptions sont purement illustratives.

/// Liste de lieux emblématiques à Kinshasa.  Chaque site est basé sur
/// des attractions réelles de la capitale congolaise.  Les coordonnées
/// sont approximatives et peuvent être ajustées lors de l’import en
/// base de données.  Les images référencent des ressources locales ou
/// peuvent être remplacées par des URL distantes.
final List<Site> fakeSites = [
  Site(
    id: 'site1',
    nom: 'Marché Central',
    description:
        'Marché populaire en plein air de Kinshasa avec ambiance locale et artisanat.',
    rating: 4.5,
    latitude: -4.320,
    longitude: 15.310,
    photos: ['assets/images/site.png'],
    prixRange: '0',
    isFeatured: true,
  ),
  Site(
    id: 'site2',
    nom: 'Jardin Botanique',
    description:
        'Jardin verdoyant idéal pour une balade, propice à la détente et à la découverte.',
    rating: 4.2,
    latitude: -4.340,
    longitude: 15.290,
    photos: ['assets/images/site.png'],
    prixRange: '5-10',
    isFeatured: false,
  ),
  Site(
    id: 'site3',
    nom: 'Ma Vallée',
    description:
        'Parc d’attractions et de détente situé dans la périphérie de Kinshasa, offrant un cadre naturel exceptionnel.',
    rating: 4.7,
    latitude: -4.300,
    longitude: 15.320,
    photos: ['assets/images/site.png'],
    prixRange: '10-20',
    isFeatured: true,
  ),
  Site(
    id: 'site4',
    nom: 'Musée National de la RDC',
    description:
        'Musée moderne présentant l’histoire et la culture de la République Démocratique du Congo.',
    rating: 4.6,
    latitude: -4.335,
    longitude: 15.330,
    photos: ['assets/images/site.png'],
    prixRange: '5-15',
    isFeatured: false,
  ),
  Site(
    id: 'site5',
    nom: 'Parc de la Vallée de la Nsele',
    description:
        'Grand parc de loisirs et de nature en bordure de Kinshasa, idéal pour les familles.',
    rating: 4.3,
    latitude: -4.310,
    longitude: 15.350,
    photos: ['assets/images/site.png'],
    prixRange: '10-25',
    isFeatured: false,
  ),
  Site(
    id: 'site6',
    nom: 'Cathédrale Notre‑Dame du Congo',
    description:
        'Imposante cathédrale de style gothique, lieu emblématique du centre‑ville.',
    rating: 4.4,
    latitude: -4.320,
    longitude: 15.305,
    photos: ['assets/images/site.png'],
    prixRange: '0',
    isFeatured: false,
  ),
  Site(
    id: 'site7',
    nom: 'Parc Présidentiel de Mont Ngaliema',
    description:
        'Parc historique offrant une vue panoramique sur la ville et le fleuve Congo.',
    rating: 4.1,
    latitude: -4.350,
    longitude: 15.290,
    photos: ['assets/images/site.png'],
    prixRange: '5-10',
    isFeatured: false,
  ),
  Site(
    id: 'site8',
    nom: 'Jardin Zoologique de Kinshasa',
    description:
        'Petit zoo urbain abritant diverses espèces locales et exotiques.',
    rating: 4.0,
    latitude: -4.340,
    longitude: 15.300,
    photos: ['assets/images/site.png'],
    prixRange: '5-15',
    isFeatured: false,
  ),
  Site(
    id: 'site9',
    nom: 'Mausolée Laurent‑Désiré Kabila',
    description:
        'Lieu de mémoire dédié à l’ancien président congolais, situé sur le mont Ngaliema.',
    rating: 4.2,
    latitude: -4.345,
    longitude: 15.290,
    photos: ['assets/images/site.png'],
    prixRange: '0',
    isFeatured: false,
  ),
  Site(
    id: 'site10',
    nom: 'Marché de la Liberté',
    description:
        'Grand marché couvert connu pour ses étals variés et son architecture moderne.',
    rating: 4.1,
    latitude: -4.315,
    longitude: 15.315,
    photos: ['assets/images/site.png'],
    prixRange: '0',
    isFeatured: false,
  ),
];

/// Liste de restaurants et bars populaires de Kinshasa.
final List<Resto> fakeRestos = [
  Resto(
    id: 'resto1',
    nom: 'Limoncello',
    description:
        'Restaurant italien réputé pour ses pizzas au feu de bois et ses pâtes fraîches.',
    rating: 4.5,
    latitude: -4.330,
    longitude: 15.280,
    photos: ['assets/images/resto.png'],
    prixRange: '20-40',
    isFeatured: true,
  ),
  Resto(
    id: 'resto2',
    nom: 'Casa Mia',
    description:
        'Cuisine méditerranéenne servie dans un décor élégant avec terrasse.',
    rating: 4.4,
    latitude: -4.320,
    longitude: 15.290,
    photos: ['assets/images/resto.png'],
    prixRange: '25-45',
    isFeatured: false,
  ),
  Resto(
    id: 'resto3',
    nom: 'Al‑Dar',
    description:
        'Restaurant libanais offrant un large choix de mezzés et grillades.',
    rating: 4.3,
    latitude: -4.335,
    longitude: 15.300,
    photos: ['assets/images/resto.png'],
    prixRange: '20-35',
    isFeatured: false,
  ),
  Resto(
    id: 'resto4',
    nom: 'Pâtisserie Nouvelle',
    description:
        'Boulangerie‑pâtisserie réputée pour ses viennoiseries et gâteaux raffinés.',
    rating: 4.6,
    latitude: -4.310,
    longitude: 15.270,
    photos: ['assets/images/resto.png'],
    prixRange: '5-20',
    isFeatured: false,
  ),
  Resto(
    id: 'resto5',
    nom: 'Planète J',
    description:
        'Bar‑restaurant branché proposant des concerts et une carte variée.',
    rating: 4.2,
    latitude: -4.340,
    longitude: 15.310,
    photos: ['assets/images/resto.png'],
    prixRange: '15-30',
    isFeatured: false,
  ),
  Resto(
    id: 'resto6',
    nom: 'Le Palais',
    description:
        'Cuisine française gastronomique dans un décor élégant et raffiné.',
    rating: 4.5,
    latitude: -4.325,
    longitude: 15.295,
    photos: ['assets/images/resto.png'],
    prixRange: '30-60',
    isFeatured: false,
  ),
  Resto(
    id: 'resto7',
    nom: 'Seray',
    description:
        'Restaurant turc proposant une sélection de kebabs, grillades et plats traditionnels.',
    rating: 4.3,
    latitude: -4.315,
    longitude: 15.300,
    photos: ['assets/images/resto.png'],
    prixRange: '20-40',
    isFeatured: false,
  ),
  Resto(
    id: 'resto8',
    nom: 'Maison des Mezzes',
    description:
        'Cuisine orientale authentique avec un choix de mezzés libanais et syriens.',
    rating: 4.1,
    latitude: -4.330,
    longitude: 15.310,
    photos: ['assets/images/resto.png'],
    prixRange: '15-35',
    isFeatured: false,
  ),
  Resto(
    id: 'resto9',
    nom: 'Café Muzik',
    description:
        'Café bar animé avec soirées jazz et ambiance lounge.',
    rating: 4.0,
    latitude: -4.320,
    longitude: 15.280,
    photos: ['assets/images/resto.png'],
    prixRange: '10-25',
    isFeatured: false,
  ),
  Resto(
    id: 'resto10',
    nom: 'Pili Pili',
    description:
        'Restaurant congolais réputé pour ses grillades épicées et ses spécialités locales.',
    rating: 4.4,
    latitude: -4.340,
    longitude: 15.320,
    photos: ['assets/images/resto.png'],
    prixRange: '15-30',
    isFeatured: false,
  ),
];

/// Liste d’hôtels populaires de Kinshasa.
final List<Hotel> fakeHotels = [
  Hotel(
    id: 'hotel1',
    nom: 'Beatrice Hotel',
    description:
        'Hôtel haut de gamme offrant des chambres confortables et un service personnalisé.',
    rating: 4.5,
    latitude: -4.330,
    longitude: 15.310,
    photos: ['assets/images/hotel.png'],
    prixRange: '120-220',
    isFeatured: true,
  ),
  Hotel(
    id: 'hotel2',
    nom: 'Fleuve Congo Hotel',
    description:
        'Hôtel de luxe situé en bordure du fleuve Congo, avec piscine et restaurant gastronomique.',
    rating: 4.6,
    latitude: -4.340,
    longitude: 15.300,
    photos: ['assets/images/hotel.png'],
    prixRange: '150-300',
    isFeatured: true,
  ),
  Hotel(
    id: 'hotel3',
    nom: 'Grand Hôtel de Kinshasa',
    description:
        'Hôtel historique du centre‑ville, idéal pour les voyages d’affaires.',
    rating: 4.3,
    latitude: -4.325,
    longitude: 15.320,
    photos: ['assets/images/hotel.png'],
    prixRange: '100-180',
    isFeatured: false,
  ),
  Hotel(
    id: 'hotel4',
    nom: 'Hilton Kinshasa',
    description:
        'Hôtel international offrant des chambres modernes et un service d’excellence.',
    rating: 4.5,
    latitude: -4.310,
    longitude: 15.280,
    photos: ['assets/images/hotel.png'],
    prixRange: '180-350',
    isFeatured: false,
  ),
  Hotel(
    id: 'hotel5',
    nom: 'Hotel Bella Riva Kinshasa',
    description:
        'Hôtel boutique avec vue sur le fleuve et atmosphère conviviale.',
    rating: 4.2,
    latitude: -4.340,
    longitude: 15.295,
    photos: ['assets/images/hotel.png'],
    prixRange: '90-150',
    isFeatured: false,
  ),
  Hotel(
    id: 'hotel6',
    nom: 'Hotel Belle Vie',
    description:
        'Hôtel quatre étoiles avec piscine et restaurants sur place.',
    rating: 4.3,
    latitude: -4.335,
    longitude: 15.315,
    photos: ['assets/images/hotel.png'],
    prixRange: '100-180',
    isFeatured: false,
  ),
  Hotel(
    id: 'hotel7',
    nom: 'Hotel Memling',
    description:
        'Hôtel emblématique de Kinshasa alliant charme classique et confort moderne.',
    rating: 4.4,
    latitude: -4.320,
    longitude: 15.300,
    photos: ['assets/images/hotel.png'],
    prixRange: '130-250',
    isFeatured: false,
  ),
  Hotel(
    id: 'hotel8',
    nom: 'Hotel Platinum',
    description:
        'Hôtel offrant des suites spacieuses et un centre de bien‑être.',
    rating: 4.1,
    latitude: -4.315,
    longitude: 15.285,
    photos: ['assets/images/hotel.png'],
    prixRange: '110-200',
    isFeatured: false,
  ),
  Hotel(
    id: 'hotel9',
    nom: 'Hotel Pour Vous',
    description:
        'Hôtel économique apprécié pour son rapport qualité/prix et son accueil chaleureux.',
    rating: 4.0,
    latitude: -4.345,
    longitude: 15.280,
    photos: ['assets/images/hotel.png'],
    prixRange: '50-100',
    isFeatured: false,
  ),
  Hotel(
    id: 'hotel10',
    nom: 'Hotel Sultani',
    description:
        'Hôtel moderne situé au cœur de la ville, avec restaurant et salle de conférence.',
    rating: 4.2,
    latitude: -4.330,
    longitude: 15.290,
    photos: ['assets/images/hotel.png'],
    prixRange: '90-170',
    isFeatured: false,
  ),
];

/// Liste d’évènements culturels et festifs se déroulant à Kinshasa.
final List<Event> fakeEvents = [
  Event(
    id: 'event1',
    nom: 'Foire Internationale de Kinshasa (FIKIN)',
    description:
        'Grande foire annuelle présentant des expositions commerciales, culturelles et gastronomiques.',
    rating: 4.5,
    latitude: -4.320,
    longitude: 15.300,
    photos: ['assets/images/event.png'],
    prixRange: '5-10',
    isFeatured: true,
  ),
  Event(
    id: 'event2',
    nom: 'Kongo River Festival',
    description:
        'Festival artistique célébrant la culture du fleuve Congo avec musique, danse et écologie.',
    rating: 4.4,
    latitude: -4.325,
    longitude: 15.310,
    photos: ['assets/images/event.png'],
    prixRange: '10-20',
    isFeatured: false,
  ),
  Event(
    id: 'event3',
    nom: 'Kinshasa Jazz Festival',
    description:
        'Festival de jazz accueillant des artistes internationaux et locaux sur plusieurs scènes.',
    rating: 4.6,
    latitude: -4.310,
    longitude: 15.320,
    photos: ['assets/images/event.png'],
    prixRange: '15-30',
    isFeatured: false,
  ),
  Event(
    id: 'event4',
    nom: 'KinAct Festival',
    description:
        'Festival d’art de rue et de performances vivantes dans les quartiers de Kinshasa.',
    rating: 4.3,
    latitude: -4.330,
    longitude: 15.280,
    photos: ['assets/images/event.png'],
    prixRange: '0-10',
    isFeatured: false,
  ),
  Event(
    id: 'event5',
    nom: 'Marathon de Kinshasa',
    description:
        'Course annuelle traversant les principaux axes de la capitale, ouverte aux amateurs et professionnels.',
    rating: 4.2,
    latitude: -4.300,
    longitude: 15.295,
    photos: ['assets/images/event.png'],
    prixRange: '10-20',
    isFeatured: false,
  ),
  Event(
    id: 'event6',
    nom: 'Kinshasa Fashion Week',
    description:
        'Semaine de la mode mettant en avant les créateurs congolais et africains.',
    rating: 4.5,
    latitude: -4.320,
    longitude: 15.290,
    photos: ['assets/images/event.png'],
    prixRange: '20-50',
    isFeatured: false,
  ),
  Event(
    id: 'event7',
    nom: 'Festival International du Cinéma de Kinshasa (FICKIN)',
    description:
        'Festival cinématographique célébrant le cinéma congolais et africain.',
    rating: 4.4,
    latitude: -4.315,
    longitude: 15.300,
    photos: ['assets/images/event.png'],
    prixRange: '10-20',
    isFeatured: false,
  ),
  Event(
    id: 'event8',
    nom: 'Salon du Livre de Kinshasa',
    description:
        'Salon consacré à la littérature et à la promotion de la lecture avec des auteurs et éditeurs.',
    rating: 4.1,
    latitude: -4.325,
    longitude: 15.305,
    photos: ['assets/images/event.png'],
    prixRange: '5-15',
    isFeatured: false,
  ),
  Event(
    id: 'event9',
    nom: 'Festival de Musique et de Tourisme',
    description:
        'Évènement combinant concerts et promotion du tourisme en RDC.',
    rating: 4.3,
    latitude: -4.340,
    longitude: 15.310,
    photos: ['assets/images/event.png'],
    prixRange: '20-30',
    isFeatured: false,
  ),
  Event(
    id: 'event10',
    nom: 'Carnaval de Kinshasa',
    description:
        'Défilé coloré avec danses, costumes et musique célébrant la culture congolaise.',
    rating: 4.5,
    latitude: -4.330,
    longitude: 15.295,
    photos: ['assets/images/event.png'],
    prixRange: '0-10',
    isFeatured: false,
  ),
];

/// Liste d’entreprises et d’organisations basées à Kinshasa.
final List<Entreprise> fakeEntreprises = [
  Entreprise(
    id: 'ent1',
    nom: 'Vodacom Congo',
    description:
        'Opérateur de téléphonie mobile majeur en RDC offrant des services de communication et d’Internet.',
    rating: 4.5,
    latitude: -4.320,
    longitude: 15.310,
    photos: ['https://logo.clearbit.com/vodacom.cd'],
    prixRange: '—',
    isFeatured: true,
  ),
  Entreprise(
    id: 'ent2',
    nom: 'Airtel Congo',
    description:
        'Fournisseur de services mobiles et Internet avec une large couverture nationale.',
    rating: 4.4,
    latitude: -4.330,
    longitude: 15.300,
    photos: ['https://logo.clearbit.com/airtel.cd'],
    prixRange: '—',
    isFeatured: false,
  ),
  Entreprise(
    id: 'ent3',
    nom: 'Orange RDC',
    description:
        'Opérateur télécom international proposant des services mobiles, Internet et financiers.',
    rating: 4.3,
    latitude: -4.325,
    longitude: 15.320,
    photos: ['https://logo.clearbit.com/orange.cd'],
    prixRange: '—',
    isFeatured: false,
  ),
  Entreprise(
    id: 'ent4',
    nom: 'Rawbank',
    description:
        'Banque commerciale offrant des services bancaires complets aux particuliers et entreprises.',
    rating: 4.2,
    latitude: -4.315,
    longitude: 15.310,
    photos: ['https://logo.clearbit.com/rawbank.com'],
    prixRange: '—',
    isFeatured: false,
  ),
  Entreprise(
    id: 'ent5',
    nom: 'Bracongo',
    description:
        'Brasserie congolaise produisant des boissons alcoolisées et non alcoolisées populaires.',
    rating: 4.1,
    latitude: -4.340,
    longitude: 15.295,
    photos: ['https://logo.clearbit.com/bracongo.cd'],
    prixRange: '—',
    isFeatured: false,
  ),
  Entreprise(
    id: 'ent6',
    nom: 'Bralima',
    description:
        'Brasserie historique connue pour ses bières et boissons appréciées en RDC.',
    rating: 4.0,
    latitude: -4.330,
    longitude: 15.285,
    photos: ['https://logo.clearbit.com/bralima.net'],
    prixRange: '—',
    isFeatured: false,
  ),
  Entreprise(
    id: 'ent7',
    nom: 'Finca RDC',
    description:
        'Institution de microfinance fournissant des prêts et des services financiers inclusifs.',
    rating: 4.2,
    latitude: -4.340,
    longitude: 15.300,
    photos: ['https://logo.clearbit.com/finca.org'],
    prixRange: '—',
    isFeatured: false,
  ),
  Entreprise(
    id: 'ent8',
    nom: 'SNEL',
    description:
        'Société Nationale d’Électricité, fournisseur principal d’électricité en RDC.',
    rating: 4.1,
    latitude: -4.320,
    longitude: 15.305,
    photos: ['https://logo.clearbit.com/snel.cd'],
    prixRange: '—',
    isFeatured: false,
  ),
  Entreprise(
    id: 'ent9',
    nom: 'Regideso',
    description:
        'Entreprise publique chargée de la distribution d’eau potable en RDC.',
    rating: 4.0,
    latitude: -4.335,
    longitude: 15.315,
    photos: ['https://logo.clearbit.com/regideso-rdc.com'],
    prixRange: '—',
    isFeatured: false,
  ),
  Entreprise(
    id: 'ent10',
    nom: 'Transco',
    description:
        'Société de transport en commun opérant les bus publics à Kinshasa.',
    rating: 3.9,
    latitude: -4.310,
    longitude: 15.290,
    photos: ['https://logo.clearbit.com/transco.cd'],
    prixRange: '—',
    isFeatured: false,
  ),
];