// The Examora icon set: line icons on a 24 px grid, 1.75 stroke, round caps and joins (brand guidelines, "Iconography").
// Icons are never filled and never multicolour: they take their colour from the text colour around them.
// Each icon is a list of path strings; the names the app already used (home, assignment, person ...) are kept.

const SHEET = 'M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8l-5-5z M14 3v5h5';
const PERSON = ['M12 11.5a3.75 3.75 0 1 0 0-7.5 3.75 3.75 0 0 0 0 7.5z', 'M4.5 20c.7-3.5 3.6-5.5 7.5-5.5s6.8 2 7.5 5.5'];
const CIRCLE = 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z';

const SHAPES = {
  shieldCheck: ['M12 3l7 3v5.5c0 4.2-2.8 7.4-7 9.5-4.2-2.1-7-5.3-7-9.5V6l7-3z', 'M9 12l2.2 2.2L15 10.5'],
  examSheet: [SHEET, 'M9 13h6', 'M9 17h4'],
  home: ['M4 11l8-7 8 7v8a1 1 0 0 1-1 1h-4v-6h-6v6H5a1 1 0 0 1-1-1v-8z'],
  person: PERSON,
  users: [
    'M9.5 11a3.25 3.25 0 1 0 0-6.5 3.25 3.25 0 0 0 0 6.5z',
    'M3 19.5c.6-3 3-4.75 6.5-4.75s5.9 1.75 6.5 4.75',
    'M15.5 4.7a3.25 3.25 0 0 1 0 6.1',
    'M17.5 14.9c1.9.5 3.1 1.9 3.5 4.1',
  ],
  userPlus: [
    'M9.5 11a3.25 3.25 0 1 0 0-6.5 3.25 3.25 0 0 0 0 6.5z',
    'M3 19.5c.6-3 3-4.75 6.5-4.75 1.4 0 2.6.3 3.6.8',
    'M18 14v6',
    'M15 17h6',
  ],
  plus: ['M12 5v14', 'M5 12h14'],
  check: ['M5 12.5l4.5 4.5L19 7.5'],
  arrowLeft: ['M19 12H5', 'M11 6l-6 6 6 6'],
  arrowRight: ['M5 12h14', 'M13 6l6 6-6 6'],
  upload: [SHEET, 'M12 17v-6', 'M9.5 13.5L12 11l2.5 2.5'],
  download: ['M12 4v11', 'M7.5 10.5L12 15l4.5-4.5', 'M5 20h14'],
  logout: ['M9 4H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h3', 'M16 8l4 4-4 4', 'M20 12H9'],
  lock: ['M6 11h12a1 1 0 0 1 1 1v7a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-7a1 1 0 0 1 1-1z', 'M8 11V8a4 4 0 0 1 8 0v3', 'M12 15v2'],
  alertCircle: [CIRCLE, 'M12 8v5', 'M12 16.2v.01'],
  infoCircle: [CIRCLE, 'M12 11v5.2', 'M12 7.8v.01'],
  checkCircle: [CIRCLE, 'M8.4 12.3l2.5 2.5 4.7-5'],
  alertTriangle: ['M12 4l9.2 16H2.8L12 4z', 'M12 10v4', 'M12 17v.01'],
  inbox: ['M4 13l2.1-6.9A2 2 0 0 1 8 4.7h8a2 2 0 0 1 1.9 1.4L20 13v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-5z', 'M4 13h4.5l1 2h5l1-2H20'],
  ban: [CIRCLE, 'M5.7 5.7l12.6 12.6'],
  flag: ['M6 21V4', 'M6 4h11l-2.6 4.5L17 13H6'],
  key: ['M9 15.5a3.75 3.75 0 1 1 3-6', 'M12 12.5L20 4.5', 'M16.5 8l2.5 2.5'],
  chart: ['M4 4v16h16', 'M8.5 16v-4', 'M12.5 16V8', 'M16.5 16v-6'],
  calendar: ['M5 6h14a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1z', 'M4 10.5h16', 'M8 3.5V7', 'M16 3.5V7'],
  timer: ['M12 21a7.5 7.5 0 1 0 0-15 7.5 7.5 0 0 0 0 15z', 'M12 9.5V13l2.2 1.6', 'M9.5 3h5'],
  award: ['M12 14.5a5 5 0 1 0 0-10 5 5 0 0 0 0 10z', 'M9.2 13.8L8 20.5l4-2.2 4 2.2-1.2-6.7', 'M10 9.6l1.5 1.5 2.7-2.8'],
  settings: ['M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z', 'M12 3v2.5', 'M12 18.5V21', 'M3 12h2.5', 'M18.5 12H21', 'M5.6 5.6l1.8 1.8', 'M16.6 16.6l1.8 1.8', 'M18.4 5.6l-1.8 1.8', 'M7.4 16.6l-1.8 1.8'],
  search: ['M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14z', 'M16.2 16.2L20 20'],
  bell: ['M6 16.5V11a6 6 0 0 1 12 0v5.5l1.5 2h-15L6 16.5z', 'M10 21h4'],
  eye: ['M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z', 'M12 14.75a2.75 2.75 0 1 0 0-5.5 2.75 2.75 0 0 0 0 5.5z'],
  eyeOff: ['M3 3l18 18', 'M10.6 5.7A9.6 9.6 0 0 1 12 5.5c6 0 9.5 6.5 9.5 6.5a16 16 0 0 1-3 3.8', 'M6.5 7.6A15.7 15.7 0 0 0 2.5 12S6 18.5 12 18.5c1.4 0 2.6-.3 3.7-.8', 'M9.9 9.9a2.75 2.75 0 0 0 3.9 3.9'],
  globe: [CIRCLE, 'M3 12h18', 'M12 3c2.5 2.5 3.6 5.5 3.6 9s-1.1 6.5-3.6 9c-2.5-2.5-3.6-5.5-3.6-9S9.5 5.5 12 3z'],
  camera: ['M4 7h9a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2z', 'M15 11l6-3.5v9L15 13'],
  mail: ['M4 6h16a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1z', 'M3.5 7.5l8.5 6 8.5-6'],
  bolt: ['M13 3L5 14h6l-1 7 8-11h-6l1-7z'],
  layers: ['M12 4l9 5-9 5-9-5 9-5z', 'M3 13.5l9 5 9-5'],
  trash: ['M4 7h16', 'M9 7V4.5h6V7', 'M6.5 7l.8 12.5h9.4L17.5 7', 'M10 11v5', 'M14 11v5'],
  edit: ['M4 20l1-4L16.5 4.5a2 2 0 0 1 2.8 0l.2.2a2 2 0 0 1 0 2.8L8 19l-4 1z', 'M14.5 6.5l3 3'],
  menu: ['M4 7h16', 'M4 12h16', 'M4 17h16'],
  close: ['M6 6l12 12', 'M18 6L6 18'],
} satisfies Record<string, string[]>;

// The names the app used before the brand set, mapped onto it. The Outline/selected pairs are the same drawing: in this
// style a selected item is shown by its colour and background, not by filling the icon.
const ALIASES = {
  arrowBack: 'arrowLeft',
  add: 'plus',
  homeOutline: 'home',
  personOutline: 'person',
  assignment: 'examSheet',
  assignmentOutline: 'examSheet',
  uploadFile: 'upload',
  error: 'alertCircle',
  info: 'infoCircle',
  success: 'checkCircle',
  warning: 'alertTriangle',
  people: 'users',
  personAdd: 'userPlus',
  block: 'ban',
  report: 'flag',
} as const;

export type IconName = keyof typeof SHAPES | keyof typeof ALIASES;

function pathsOf(name: IconName): readonly string[] {
  const resolved = (name in ALIASES ? ALIASES[name as keyof typeof ALIASES] : name) as keyof typeof SHAPES;
  return SHAPES[resolved];
}

export function Icon({ name, size = 24, className }: { name: IconName; size?: number; className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      width={size}
      height={size}
      aria-hidden="true"
      focusable="false"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.75"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      {pathsOf(name).map((d) => (
        <path key={d} d={d} />
      ))}
    </svg>
  );
}
