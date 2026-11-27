import type { Round, TestPolicy } from '../model/types';

/**
 * Hand-checked details for well-known colleges, layered on top of the federal
 * IPEDS data (see scripts/build-colleges.ts). IPEDS supplies each college's
 * name, location, admit rate, test score ranges and enrollment; it does not
 * publish GPAs, early application rounds, legacy policies or admit rates by
 * residency, so those come from here.
 *
 *   id        IPEDS unit ID
 *   slug      readable key, only for humans editing this file
 *   name      friendlier display name than the official IPEDS name
 *   gpa       estimated average unweighted GPA of admitted first-years
 *   test      current test policy (IPEDS lags behind recent changes)
 *   rounds    early rounds offered in addition to Regular Decision
 *   legacy    whether legacy (alumni parent) status is considered
 *   inState / outState   admit rates by residency for public universities
 *
 * Values are approximate, from recent Common Data Set reports and college
 * announcements. Confirm details on each college's website.
 */
export interface CuratedCollege {
  id: string;
  slug: string;
  name: string;
  short?: string;
  aka?: readonly string[];
  gpa: number;
  test: TestPolicy;
  rounds: readonly Round[];
  legacy: boolean;
  inState?: number;
  outState?: number;
  liberalArts?: boolean;
  tags?: readonly string[];
}

export const CURATED: readonly CuratedCollege[] = [
  { id: '166027', slug: 'harvard', name: 'Harvard University', short: 'Harvard', gpa: 3.95, test: 'required', rounds: ['REA'], legacy: true },
  { id: '243744', slug: 'stanford', name: 'Stanford University', short: 'Stanford', gpa: 3.95, test: 'required', rounds: ['REA'], legacy: false },
  { id: '166683', slug: 'mit', name: 'Massachusetts Institute of Technology', short: 'MIT', gpa: 3.95, test: 'required', rounds: ['EA'], legacy: false },
  { id: '110404', slug: 'caltech', name: 'California Institute of Technology', short: 'Caltech', gpa: 3.96, test: 'required', rounds: ['REA'], legacy: false },
  { id: '186131', slug: 'princeton', name: 'Princeton University', short: 'Princeton', gpa: 3.95, test: 'required', rounds: ['REA'], legacy: true },
  { id: '130794', slug: 'yale', name: 'Yale University', short: 'Yale', gpa: 3.95, test: 'required', rounds: ['REA'], legacy: true },
  { id: '190150', slug: 'columbia', name: 'Columbia University', short: 'Columbia', gpa: 3.92, test: 'optional', rounds: ['ED'], legacy: true },
  { id: '215062', slug: 'upenn', name: 'University of Pennsylvania', short: 'Penn', aka: ['UPenn', 'Wharton'], gpa: 3.92, test: 'required', rounds: ['ED'], legacy: true },
  { id: '217156', slug: 'brown', name: 'Brown University', short: 'Brown', gpa: 3.94, test: 'required', rounds: ['ED'], legacy: true },
  { id: '182670', slug: 'dartmouth', name: 'Dartmouth College', short: 'Dartmouth', gpa: 3.92, test: 'required', rounds: ['ED'], legacy: true },
  { id: '190415', slug: 'cornell', name: 'Cornell University', short: 'Cornell', gpa: 3.9, test: 'required', rounds: ['ED'], legacy: true },
  { id: '144050', slug: 'uchicago', name: 'University of Chicago', short: 'UChicago', gpa: 3.93, test: 'optional', rounds: ['ED', 'ED2', 'EA'], legacy: true },
  { id: '198419', slug: 'duke', name: 'Duke University', short: 'Duke', gpa: 3.94, test: 'required', rounds: ['ED'], legacy: true },
  { id: '162928', slug: 'jhu', name: 'Johns Hopkins University', short: 'Johns Hopkins', aka: ['JHU', 'Hopkins'], gpa: 3.95, test: 'required', rounds: ['ED', 'ED2'], legacy: false },
  { id: '147767', slug: 'northwestern', name: 'Northwestern University', short: 'Northwestern', gpa: 3.92, test: 'optional', rounds: ['ED'], legacy: true },
  { id: '227757', slug: 'rice', name: 'Rice University', short: 'Rice', gpa: 3.94, test: 'optional', rounds: ['ED'], legacy: true },
  { id: '221999', slug: 'vanderbilt', name: 'Vanderbilt University', short: 'Vanderbilt', gpa: 3.93, test: 'optional', rounds: ['ED', 'ED2'], legacy: true },
  { id: '179867', slug: 'washu', name: 'Washington University in St. Louis', short: 'WashU', gpa: 3.92, test: 'optional', rounds: ['ED', 'ED2'], legacy: false },
  { id: '152080', slug: 'notre-dame', name: 'University of Notre Dame', short: 'Notre Dame', gpa: 3.92, test: 'optional', rounds: ['REA'], legacy: true },
  { id: '131496', slug: 'georgetown', name: 'Georgetown University', short: 'Georgetown', gpa: 3.9, test: 'required', rounds: ['REA'], legacy: true },
  { id: '139658', slug: 'emory', name: 'Emory University', short: 'Emory', gpa: 3.88, test: 'optional', rounds: ['ED', 'ED2'], legacy: true },
  { id: '211440', slug: 'cmu', name: 'Carnegie Mellon University', short: 'Carnegie Mellon', aka: ['CMU'], gpa: 3.9, test: 'required', rounds: ['ED', 'ED2'], legacy: true },
  { id: '123961', slug: 'usc', name: 'University of Southern California', short: 'USC', gpa: 3.88, test: 'optional', rounds: ['EA'], legacy: false },
  { id: '168148', slug: 'tufts', name: 'Tufts University', short: 'Tufts', gpa: 3.9, test: 'optional', rounds: ['ED', 'ED2'], legacy: true },
  { id: '193900', slug: 'nyu', name: 'New York University', short: 'NYU', gpa: 3.85, test: 'optional', rounds: ['ED', 'ED2'], legacy: true },
  { id: '164988', slug: 'bu', name: 'Boston University', short: 'BU', gpa: 3.85, test: 'optional', rounds: ['ED', 'ED2'], legacy: true },
  { id: '164924', slug: 'bc', name: 'Boston College', short: 'Boston College', aka: ['BC'], gpa: 3.9, test: 'optional', rounds: ['ED', 'ED2'], legacy: true },
  { id: '167358', slug: 'northeastern', name: 'Northeastern University', short: 'Northeastern', gpa: 3.85, test: 'optional', rounds: ['ED', 'ED2', 'EA'], legacy: false },
  { id: '160755', slug: 'tulane', name: 'Tulane University', short: 'Tulane', gpa: 3.7, test: 'optional', rounds: ['ED', 'ED2', 'EA'], legacy: true },
  { id: '195030', slug: 'rochester', name: 'University of Rochester', short: 'Rochester', gpa: 3.85, test: 'optional', rounds: ['ED', 'ED2'], legacy: true },
  { id: '201645', slug: 'cwru', name: 'Case Western Reserve University', short: 'Case Western', aka: ['CWRU'], gpa: 3.85, test: 'optional', rounds: ['ED', 'ED2', 'EA'], legacy: true },
  { id: '165015', slug: 'brandeis', name: 'Brandeis University', short: 'Brandeis', gpa: 3.85, test: 'optional', rounds: ['ED', 'ED2'], legacy: true },
  { id: '213543', slug: 'lehigh', name: 'Lehigh University', short: 'Lehigh', gpa: 3.7, test: 'optional', rounds: ['ED', 'ED2'], legacy: true },
  { id: '216597', slug: 'villanova', name: 'Villanova University', short: 'Villanova', gpa: 3.85, test: 'optional', rounds: ['ED', 'ED2', 'EA'], legacy: true },
  { id: '199847', slug: 'wake-forest', name: 'Wake Forest University', short: 'Wake Forest', gpa: 3.85, test: 'optional', rounds: ['ED', 'ED2', 'EA'], legacy: true },
  { id: '135726', slug: 'miami', name: 'University of Miami', short: 'Miami', aka: ['UM', 'U Miami'], gpa: 3.8, test: 'optional', rounds: ['ED', 'ED2', 'EA'], legacy: true },
  { id: '194824', slug: 'rpi', name: 'Rensselaer Polytechnic Institute', short: 'RPI', aka: ['Rensselaer'], gpa: 3.85, test: 'optional', rounds: ['ED', 'ED2', 'EA'], legacy: true },
  { id: '168421', slug: 'wpi', name: 'Worcester Polytechnic Institute', short: 'WPI', gpa: 3.85, test: 'optional', rounds: ['ED', 'ED2', 'EA'], legacy: true },
  { id: '186867', slug: 'stevens', name: 'Stevens Institute of Technology', short: 'Stevens', gpa: 3.8, test: 'optional', rounds: ['ED', 'ED2', 'EA'], legacy: true },
  { id: '196413', slug: 'syracuse', name: 'Syracuse University', short: 'Syracuse', gpa: 3.6, test: 'optional', rounds: ['ED'], legacy: true },
  { id: '191241', slug: 'fordham', name: 'Fordham University', short: 'Fordham', gpa: 3.7, test: 'optional', rounds: ['ED', 'EA'], legacy: true },
  { id: '131469', slug: 'gwu', name: 'George Washington University', short: 'GW', aka: ['GWU', 'George Washington'], gpa: 3.75, test: 'optional', rounds: ['ED', 'ED2'], legacy: true },
  { id: '131159', slug: 'american', name: 'American University', short: 'American', gpa: 3.7, test: 'optional', rounds: ['ED', 'ED2', 'EA'], legacy: true },
  { id: '228246', slug: 'smu', name: 'Southern Methodist University', short: 'SMU', gpa: 3.7, test: 'optional', rounds: ['ED', 'ED2', 'EA'], legacy: true },
  { id: '223232', slug: 'baylor', name: 'Baylor University', short: 'Baylor', gpa: 3.7, test: 'optional', rounds: ['ED', 'EA'], legacy: true },
  { id: '228875', slug: 'tcu', name: 'Texas Christian University', short: 'TCU', gpa: 3.6, test: 'optional', rounds: ['ED', 'EA'], legacy: true },
  { id: '121150', slug: 'pepperdine', name: 'Pepperdine University', short: 'Pepperdine', gpa: 3.7, test: 'optional', rounds: ['EA'], legacy: false },
  { id: '122931', slug: 'santa-clara', name: 'Santa Clara University', short: 'Santa Clara', gpa: 3.8, test: 'optional', rounds: ['ED', 'ED2', 'EA'], legacy: false },
  { id: '117946', slug: 'lmu', name: 'Loyola Marymount University', short: 'LMU', gpa: 3.75, test: 'optional', rounds: ['ED', 'EA'], legacy: false },
  { id: '131520', slug: 'howard', name: 'Howard University', short: 'Howard', gpa: 3.5, test: 'optional', rounds: ['ED', 'EA'], legacy: true, tags: ['HBCU'] },
  { id: '230038', slug: 'byu', name: 'Brigham Young University', short: 'BYU', gpa: 3.85, test: 'optional', rounds: [], legacy: false },
  { id: '212054', slug: 'drexel', name: 'Drexel University', short: 'Drexel', gpa: 3.6, test: 'optional', rounds: ['ED', 'EA'], legacy: true },
  { id: '235316', slug: 'gonzaga', name: 'Gonzaga University', short: 'Gonzaga', gpa: 3.7, test: 'optional', rounds: ['EA'], legacy: true },
  { id: '165662', slug: 'emerson', name: 'Emerson College', short: 'Emerson', gpa: 3.6, test: 'optional', rounds: ['ED', 'EA'], legacy: true },
  { id: '164580', slug: 'babson', name: 'Babson College', short: 'Babson', gpa: 3.7, test: 'optional', rounds: ['ED', 'ED2', 'EA'], legacy: true },
  { id: '110662', slug: 'ucla', name: 'University of California, Los Angeles', short: 'UCLA', gpa: 3.9, test: 'blind', rounds: [], legacy: false, inState: 0.095, outState: 0.08 },
  { id: '110635', slug: 'berkeley', name: 'University of California, Berkeley', short: 'UC Berkeley', aka: ['Cal', 'Berkeley', 'UCB'], gpa: 3.9, test: 'blind', rounds: [], legacy: false, inState: 0.13, outState: 0.09 },
  { id: '110680', slug: 'ucsd', name: 'University of California, San Diego', short: 'UC San Diego', aka: ['UCSD'], gpa: 3.85, test: 'blind', rounds: [], legacy: false, inState: 0.26, outState: 0.23 },
  { id: '110653', slug: 'uci', name: 'University of California, Irvine', short: 'UC Irvine', aka: ['UCI'], gpa: 3.8, test: 'blind', rounds: [], legacy: false, inState: 0.28, outState: 0.24 },
  { id: '110705', slug: 'ucsb', name: 'University of California, Santa Barbara', short: 'UC Santa Barbara', aka: ['UCSB'], gpa: 3.8, test: 'blind', rounds: [], legacy: false, inState: 0.28, outState: 0.28 },
  { id: '110644', slug: 'ucd', name: 'University of California, Davis', short: 'UC Davis', aka: ['UCD'], gpa: 3.75, test: 'blind', rounds: [], legacy: false, inState: 0.43, outState: 0.4 },
  { id: '110714', slug: 'ucsc', name: 'University of California, Santa Cruz', short: 'UC Santa Cruz', aka: ['UCSC'], gpa: 3.6, test: 'blind', rounds: [], legacy: false, inState: 0.63, outState: 0.63 },
  { id: '110671', slug: 'ucr', name: 'University of California, Riverside', short: 'UC Riverside', aka: ['UCR'], gpa: 3.5, test: 'blind', rounds: [], legacy: false, inState: 0.64, outState: 0.6 },
  { id: '110422', slug: 'cal-poly', name: 'California Polytechnic State University, San Luis Obispo', short: 'Cal Poly SLO', aka: ['Cal Poly'], gpa: 3.8, test: 'blind', rounds: [], legacy: false },
  { id: '122409', slug: 'sdsu', name: 'San Diego State University', short: 'San Diego State', aka: ['SDSU'], gpa: 3.75, test: 'blind', rounds: [], legacy: false },
  { id: '170976', slug: 'umich', name: 'University of Michigan', short: 'Michigan', aka: ['UMich', 'U of M', 'Ann Arbor'], gpa: 3.88, test: 'optional', rounds: ['EA'], legacy: false, inState: 0.28, outState: 0.13 },
  { id: '234076', slug: 'uva', name: 'University of Virginia', short: 'UVA', aka: ['Virginia'], gpa: 3.92, test: 'optional', rounds: ['ED', 'EA'], legacy: false, inState: 0.25, outState: 0.13 },
  { id: '199120', slug: 'unc', name: 'University of North Carolina at Chapel Hill', short: 'UNC', aka: ['Chapel Hill', 'UNC Chapel Hill'], gpa: 3.9, test: 'required', rounds: ['EA'], legacy: false, inState: 0.41, outState: 0.085 },
  { id: '139755', slug: 'gatech', name: 'Georgia Institute of Technology', short: 'Georgia Tech', aka: ['GT', 'GaTech'], gpa: 3.92, test: 'required', rounds: ['EA'], legacy: false, inState: 0.32, outState: 0.1 },
  { id: '134130', slug: 'uf', name: 'University of Florida', short: 'Florida', aka: ['UF'], gpa: 3.9, test: 'required', rounds: [], legacy: false, inState: 0.27, outState: 0.19 },
  { id: '228778', slug: 'ut-austin', name: 'University of Texas at Austin', short: 'UT Austin', aka: ['Texas', 'UT'], gpa: 3.8, test: 'required', rounds: ['EA'], legacy: false, inState: 0.32, outState: 0.14 },
  { id: '240444', slug: 'uw-madison', name: 'University of Wisconsin–Madison', short: 'Wisconsin', aka: ['UW Madison', 'UW-Madison'], gpa: 3.85, test: 'optional', rounds: ['EA'], legacy: false, inState: 0.62, outState: 0.38 },
  { id: '145637', slug: 'uiuc', name: 'University of Illinois Urbana-Champaign', short: 'Illinois', aka: ['UIUC', 'U of I'], gpa: 3.85, test: 'optional', rounds: ['EA'], legacy: false, inState: 0.48, outState: 0.41 },
  { id: '236948', slug: 'uw', name: 'University of Washington', short: 'UW', aka: ['UDub', 'Washington'], gpa: 3.85, test: 'optional', rounds: [], legacy: false, inState: 0.6, outState: 0.37 },
  { id: '204796', slug: 'osu', name: 'The Ohio State University', short: 'Ohio State', aka: ['OSU'], gpa: 3.75, test: 'optional', rounds: ['EA'], legacy: false, inState: 0.58, outState: 0.47 },
  { id: '243780', slug: 'purdue', name: 'Purdue University', short: 'Purdue', gpa: 3.7, test: 'required', rounds: ['EA'], legacy: false, inState: 0.66, outState: 0.46 },
  { id: '214777', slug: 'psu', name: 'Pennsylvania State University', short: 'Penn State', aka: ['PSU'], gpa: 3.6, test: 'optional', rounds: ['EA'], legacy: false, inState: 0.57, outState: 0.54 },
  { id: '186380', slug: 'rutgers', name: 'Rutgers University–New Brunswick', short: 'Rutgers', gpa: 3.6, test: 'optional', rounds: ['EA'], legacy: false, inState: 0.67, outState: 0.62 },
  { id: '163286', slug: 'umd', name: 'University of Maryland, College Park', short: 'Maryland', aka: ['UMD'], gpa: 3.8, test: 'optional', rounds: ['EA'], legacy: false, inState: 0.47, outState: 0.43 },
  { id: '233921', slug: 'vt', name: 'Virginia Tech', aka: ['VT', 'Virginia Polytechnic'], gpa: 3.7, test: 'optional', rounds: ['ED', 'EA'], legacy: false, inState: 0.6, outState: 0.55 },
  { id: '228723', slug: 'tamu', name: 'Texas A&M University', short: 'Texas A&M', aka: ['TAMU', 'A&M'], gpa: 3.7, test: 'optional', rounds: [], legacy: false, inState: 0.65, outState: 0.55 },
  { id: '139959', slug: 'uga', name: 'University of Georgia', short: 'Georgia', aka: ['UGA'], gpa: 3.9, test: 'required', rounds: ['EA'], legacy: false, inState: 0.44, outState: 0.31 },
  { id: '217882', slug: 'clemson', name: 'Clemson University', short: 'Clemson', gpa: 3.8, test: 'optional', rounds: ['EA'], legacy: false, inState: 0.54, outState: 0.35 },
  { id: '231624', slug: 'wm', name: 'William & Mary', aka: ['W&M', 'College of William and Mary'], gpa: 3.9, test: 'optional', rounds: ['ED', 'ED2'], legacy: false, inState: 0.41, outState: 0.29 },
  { id: '199193', slug: 'ncsu', name: 'North Carolina State University', short: 'NC State', aka: ['NCSU'], gpa: 3.8, test: 'optional', rounds: ['EA'], legacy: false, inState: 0.47, outState: 0.33 },
  { id: '215293', slug: 'pitt', name: 'University of Pittsburgh', short: 'Pitt', gpa: 3.7, test: 'optional', rounds: [], legacy: false, inState: 0.55, outState: 0.48 },
  { id: '126614', slug: 'cu-boulder', name: 'University of Colorado Boulder', short: 'CU Boulder', aka: ['Colorado'], gpa: 3.6, test: 'optional', rounds: ['EA'], legacy: false, inState: 0.85, outState: 0.8 },
  { id: '209551', slug: 'uoregon', name: 'University of Oregon', short: 'Oregon', gpa: 3.6, test: 'optional', rounds: ['EA'], legacy: false },
  { id: '104179', slug: 'arizona', name: 'University of Arizona', short: 'Arizona', gpa: 3.5, test: 'optional', rounds: [], legacy: false },
  { id: '104151', slug: 'asu', name: 'Arizona State University', short: 'Arizona State', aka: ['ASU'], gpa: 3.5, test: 'optional', rounds: [], legacy: false },
  { id: '151351', slug: 'iu', name: 'Indiana University Bloomington', short: 'Indiana', aka: ['IU'], gpa: 3.7, test: 'optional', rounds: ['EA'], legacy: false, inState: 0.85, outState: 0.78 },
  { id: '171100', slug: 'msu', name: 'Michigan State University', short: 'Michigan State', aka: ['MSU'], gpa: 3.6, test: 'optional', rounds: ['EA'], legacy: false, inState: 0.87, outState: 0.83 },
  { id: '174066', slug: 'umn', name: 'University of Minnesota Twin Cities', short: 'Minnesota', aka: ['UMN'], gpa: 3.7, test: 'optional', rounds: ['EA'], legacy: false, inState: 0.8, outState: 0.75 },
  { id: '153658', slug: 'uiowa', name: 'University of Iowa', short: 'Iowa', gpa: 3.7, test: 'optional', rounds: [], legacy: false },
  { id: '100751', slug: 'alabama', name: 'University of Alabama', short: 'Alabama', gpa: 3.7, test: 'optional', rounds: ['EA'], legacy: false, inState: 0.8, outState: 0.75 },
  { id: '100858', slug: 'auburn', name: 'Auburn University', short: 'Auburn', gpa: 3.8, test: 'optional', rounds: ['EA'], legacy: false, inState: 0.6, outState: 0.42 },
  { id: '159391', slug: 'lsu', name: 'Louisiana State University', short: 'LSU', gpa: 3.5, test: 'optional', rounds: [], legacy: false },
  { id: '218663', slug: 'sc', name: 'University of South Carolina', short: 'South Carolina', aka: ['UofSC'], gpa: 3.7, test: 'optional', rounds: ['EA'], legacy: false, inState: 0.68, outState: 0.58 },
  { id: '221759', slug: 'utk', name: 'University of Tennessee, Knoxville', short: 'Tennessee', aka: ['UTK'], gpa: 3.8, test: 'optional', rounds: ['EA'], legacy: false, inState: 0.62, outState: 0.45 },
  { id: '134097', slug: 'fsu', name: 'Florida State University', short: 'Florida State', aka: ['FSU'], gpa: 3.85, test: 'required', rounds: [], legacy: false, inState: 0.28, outState: 0.19 },
  { id: '132903', slug: 'ucf', name: 'University of Central Florida', short: 'UCF', gpa: 3.7, test: 'required', rounds: [], legacy: false },
  { id: '129020', slug: 'uconn', name: 'University of Connecticut', short: 'UConn', gpa: 3.75, test: 'optional', rounds: ['EA'], legacy: false, inState: 0.62, outState: 0.52 },
  { id: '166629', slug: 'umass', name: 'University of Massachusetts Amherst', short: 'UMass Amherst', aka: ['UMass'], gpa: 3.8, test: 'optional', rounds: ['EA'], legacy: false, inState: 0.66, outState: 0.55 },
  { id: '196079', slug: 'binghamton', name: 'Binghamton University', short: 'Binghamton', aka: ['SUNY Binghamton'], gpa: 3.75, test: 'optional', rounds: ['EA'], legacy: false, inState: 0.4, outState: 0.37 },
  { id: '196097', slug: 'stony-brook', name: 'Stony Brook University', short: 'Stony Brook', aka: ['SUNY Stony Brook'], gpa: 3.8, test: 'optional', rounds: ['EA'], legacy: false },
  { id: '196088', slug: 'buffalo', name: 'University at Buffalo', short: 'Buffalo', aka: ['UB', 'SUNY Buffalo'], gpa: 3.6, test: 'optional', rounds: ['EA'], legacy: false },
  { id: '130943', slug: 'delaware', name: 'University of Delaware', short: 'Delaware', aka: ['UD'], gpa: 3.7, test: 'optional', rounds: ['EA'], legacy: false },
  { id: '216339', slug: 'temple', name: 'Temple University', short: 'Temple', gpa: 3.4, test: 'optional', rounds: ['EA'], legacy: false },
  { id: '204024', slug: 'miami-oh', name: 'Miami University', short: 'Miami (OH)', aka: ['Miami Ohio'], gpa: 3.7, test: 'optional', rounds: ['ED', 'EA'], legacy: false },
  { id: '178396', slug: 'mizzou', name: 'University of Missouri', short: 'Mizzou', aka: ['Missouri'], gpa: 3.6, test: 'optional', rounds: [], legacy: false },
  { id: '230764', slug: 'utah', name: 'University of Utah', short: 'Utah', gpa: 3.6, test: 'optional', rounds: [], legacy: false },
  { id: '126775', slug: 'mines', name: 'Colorado School of Mines', short: 'Mines', gpa: 3.85, test: 'optional', rounds: ['EA'], legacy: false },
  { id: '232423', slug: 'jmu', name: 'James Madison University', short: 'JMU', gpa: 3.6, test: 'optional', rounds: ['EA'], legacy: false },
  { id: '228787', slug: 'utd', name: 'University of Texas at Dallas', short: 'UT Dallas', aka: ['UTD'], gpa: 3.7, test: 'optional', rounds: [], legacy: false },
  { id: '225511', slug: 'uh', name: 'University of Houston', short: 'Houston', aka: ['UH'], gpa: 3.5, test: 'optional', rounds: [], legacy: false },
  { id: '155317', slug: 'ku', name: 'University of Kansas', short: 'Kansas', aka: ['KU'], gpa: 3.6, test: 'optional', rounds: [], legacy: false },
  { id: '153603', slug: 'iastate', name: 'Iowa State University', short: 'Iowa State', aka: ['ISU'], gpa: 3.6, test: 'optional', rounds: [], legacy: false },
  { id: '181464', slug: 'unl', name: 'University of Nebraska–Lincoln', short: 'Nebraska', aka: ['UNL'], gpa: 3.6, test: 'optional', rounds: [], legacy: false },
  { id: '207500', slug: 'ou', name: 'University of Oklahoma', short: 'Oklahoma', aka: ['OU'], gpa: 3.6, test: 'optional', rounds: [], legacy: false },
  { id: '168342', slug: 'williams', name: 'Williams College', short: 'Williams', gpa: 3.93, test: 'optional', rounds: ['ED'], legacy: true, liberalArts: true },
  { id: '164465', slug: 'amherst', name: 'Amherst College', short: 'Amherst', gpa: 3.93, test: 'optional', rounds: ['ED'], legacy: false, liberalArts: true },
  { id: '216287', slug: 'swarthmore', name: 'Swarthmore College', short: 'Swarthmore', gpa: 3.92, test: 'optional', rounds: ['ED', 'ED2'], legacy: true, liberalArts: true },
  { id: '121345', slug: 'pomona', name: 'Pomona College', short: 'Pomona', gpa: 3.92, test: 'optional', rounds: ['ED', 'ED2'], legacy: false, liberalArts: true },
  { id: '161004', slug: 'bowdoin', name: 'Bowdoin College', short: 'Bowdoin', gpa: 3.9, test: 'optional', rounds: ['ED', 'ED2'], legacy: true, liberalArts: true },
  { id: '168218', slug: 'wellesley', name: 'Wellesley College', short: 'Wellesley', gpa: 3.9, test: 'optional', rounds: ['ED', 'ED2'], legacy: true, liberalArts: true, tags: ['Women’s college'] },
  { id: '230959', slug: 'middlebury', name: 'Middlebury College', short: 'Middlebury', gpa: 3.9, test: 'optional', rounds: ['ED', 'ED2'], legacy: true, liberalArts: true },
  { id: '173258', slug: 'carleton', name: 'Carleton College', short: 'Carleton', gpa: 3.85, test: 'optional', rounds: ['ED', 'ED2'], legacy: true, liberalArts: true },
  { id: '112260', slug: 'cmc', name: 'Claremont McKenna College', short: 'Claremont McKenna', aka: ['CMC'], gpa: 3.9, test: 'optional', rounds: ['ED', 'ED2'], legacy: false, liberalArts: true },
  { id: '115409', slug: 'hmc', name: 'Harvey Mudd College', short: 'Harvey Mudd', gpa: 3.93, test: 'optional', rounds: ['ED', 'ED2'], legacy: false, liberalArts: true },
  { id: '198385', slug: 'davidson', name: 'Davidson College', short: 'Davidson', gpa: 3.9, test: 'optional', rounds: ['ED', 'ED2'], legacy: true, liberalArts: true },
  { id: '161086', slug: 'colby', name: 'Colby College', short: 'Colby', gpa: 3.85, test: 'optional', rounds: ['ED', 'ED2'], legacy: true, liberalArts: true },
  { id: '189097', slug: 'barnard', name: 'Barnard College', short: 'Barnard', gpa: 3.9, test: 'optional', rounds: ['ED'], legacy: true, liberalArts: true, tags: ['Women’s college'] },
  { id: '197133', slug: 'vassar', name: 'Vassar College', short: 'Vassar', gpa: 3.9, test: 'optional', rounds: ['ED', 'ED2'], legacy: true, liberalArts: true },
  { id: '191515', slug: 'hamilton', name: 'Hamilton College', short: 'Hamilton', gpa: 3.9, test: 'optional', rounds: ['ED', 'ED2'], legacy: true, liberalArts: true },
  { id: '212911', slug: 'haverford', name: 'Haverford College', short: 'Haverford', gpa: 3.9, test: 'optional', rounds: ['ED', 'ED2'], legacy: true, liberalArts: true },
  { id: '153384', slug: 'grinnell', name: 'Grinnell College', short: 'Grinnell', gpa: 3.85, test: 'optional', rounds: ['ED', 'ED2'], legacy: true, liberalArts: true },
  { id: '190099', slug: 'colgate', name: 'Colgate University', short: 'Colgate', gpa: 3.85, test: 'optional', rounds: ['ED', 'ED2'], legacy: true, liberalArts: true },
  { id: '234207', slug: 'wlu', name: 'Washington and Lee University', short: 'Washington and Lee', aka: ['W&L', 'WLU'], gpa: 3.9, test: 'optional', rounds: ['ED', 'ED2'], legacy: false, liberalArts: true },
  { id: '167835', slug: 'smith', name: 'Smith College', short: 'Smith', gpa: 3.85, test: 'optional', rounds: ['ED', 'ED2'], legacy: true, liberalArts: true, tags: ['Women’s college'] },
  { id: '204501', slug: 'oberlin', name: 'Oberlin College', short: 'Oberlin', gpa: 3.7, test: 'optional', rounds: ['ED', 'ED2'], legacy: true, liberalArts: true },
  { id: '173902', slug: 'macalester', name: 'Macalester College', short: 'Macalester', gpa: 3.85, test: 'optional', rounds: ['ED', 'ED2'], legacy: true, liberalArts: true },
  { id: '160977', slug: 'bates', name: 'Bates College', short: 'Bates', gpa: 3.85, test: 'optional', rounds: ['ED', 'ED2'], legacy: true, liberalArts: true },
  { id: '130697', slug: 'wesleyan', name: 'Wesleyan University', short: 'Wesleyan', gpa: 3.85, test: 'optional', rounds: ['ED', 'ED2'], legacy: false, liberalArts: true },
  { id: '120254', slug: 'occidental', name: 'Occidental College', short: 'Occidental', aka: ['Oxy'], gpa: 3.7, test: 'optional', rounds: ['ED', 'ED2'], legacy: false, liberalArts: true },
  { id: '233374', slug: 'richmond', name: 'University of Richmond', short: 'Richmond', gpa: 3.85, test: 'optional', rounds: ['ED', 'ED2', 'EA'], legacy: true, liberalArts: true },
  { id: '141060', slug: 'spelman', name: 'Spelman College', short: 'Spelman', gpa: 3.6, test: 'optional', rounds: ['ED', 'EA'], legacy: true, liberalArts: true, tags: ['Women’s college', 'HBCU'] },
  { id: '140553', slug: 'morehouse', name: 'Morehouse College', short: 'Morehouse', gpa: 3.3, test: 'optional', rounds: ['ED', 'EA'], legacy: true, liberalArts: true, tags: ['Men’s college', 'HBCU'] },
];

const ID_BY_SLUG: ReadonlyMap<string, string> = new Map(CURATED.map((c) => [c.slug, c.id]));

/** IPEDS ID for a curated college's slug, e.g. idForSlug('mit') → '166683'. */
export function idForSlug(slug: string): string {
  const id = ID_BY_SLUG.get(slug);
  if (!id) throw new Error(`Unknown college slug: ${slug}`);
  return id;
}
