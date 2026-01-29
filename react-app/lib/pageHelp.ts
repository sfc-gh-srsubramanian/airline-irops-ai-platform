export const PAGE_HELP = {
  dashboard: "Real-time overview of flight operations including delays, cancellations, on-time performance (OTP), and hub-level statistics. Use filters to narrow by time range, hub, or status.",
  crew: "Find and assign available crew members to flights missing captains or first officers. AI-powered scoring ranks candidates by fit, qualifications, and duty time remaining.",
  ghost: "Ghost flights are scheduled flights missing critical resources (crew or aircraft). Click Resolve to get AI recommendations and execute fixes like crew assignment or aircraft swaps.",
  disruptions: "Track active disruptions (weather, mechanical, ATC) and their cascade effects. View cost breakdowns and downstream flight impacts to prioritize recovery actions.",
  contract: "Validate crew assignments against FAA regulations and union contracts. Check duty time limits, rest requirements, and aircraft type qualifications before finalizing assignments.",
  assistant: "Ask natural language questions about flight operations, crew availability, delays, and more. Powered by Snowflake Cortex AI with access to real-time operational data.",
} as const;

export type PageHelpKey = keyof typeof PAGE_HELP;
