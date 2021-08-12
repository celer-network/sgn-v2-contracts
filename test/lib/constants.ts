import { parseUnits } from '@ethersproject/units';

export const GOVERN_PROPOSAL_DEPOSIT = 100;
export const GOVERN_VOTE_TIMEOUT = 20;
export const SLASH_TIMEOUT = 50;
export const MIN_VALIDATOR_NUM = 1;
export const MAX_VALIDATOR_NUM = 20;
export const MIN_STAKING_POOL = parseUnits('4');
export const ADVANCE_NOTICE_PERIOD = 10;
export const DPOS_GO_LIVE_TIMEOUT = 20;

export const MIN_SELF_STAKE = parseUnits('2');
export const CANDIDATE_STAKE = parseUnits('3'); // smaller than MIN_STAKING_POOL for testing purpose
export const DELEGATOR_STAKE = parseUnits('6');

export const COMMISSION_RATE = 100;
export const RATE_LOCK_END_TIME = 2;

export const TYPE_VALIDATOR_ADD = 0;
export const TYPE_VALIDATOR_REMOVAL = 1;

export const SUB_FEE = parseUnits('100000000', 'wei');

export const HASHED_NULL = '0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470';

export const ZERO_ADDR = '0x0000000000000000000000000000000000000000';
export const ONE_ADDR = '0x0000000000000000000000000000000000000000';
