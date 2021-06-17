#ifndef TIME_SERIES_RAW_FORMATTER_HEADER
#define TIME_SERIES_RAW_FORMATTER_HEADER

#include "ParseParameters.h"

#include "BenchTypeSupportImpl.h"

using namespace Bench::TestController;

class TimeSeriesRawFormatter {
public:
  int format(const Report& report, std::ostream& output_stream, const ParseParameters& parse_parameters);
};

#endif
