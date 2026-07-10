import { calculateEstimate } from './src/model';

const r = calculateEstimate(1440);
console.log('Prisoners       ', r.prisoners);
console.log('Houseblocks     ', r.houseblocks, ' (expected 6)');
console.log('GIFA            ', r.requiredGIFA, ' (expected 56706)');
console.log('Acres           ', r.requiredAcres, ' (expected 51)');
console.log('Programme wks   ', r.programmeWeeks, ' (expected 154)');
console.log('TOTAL           ', r.total.toFixed(2), ' (expected 513692211.15)');
console.log('Delta vs Excel  ', (r.total - 513692211.15).toFixed(2));
