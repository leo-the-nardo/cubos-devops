// boilerplate
import { register } from 'module';
import { Hook, createAddHookMessageChannel } from 'import-in-the-middle';
const { registerOptions, waitForAllMessagesAcknowledged } = createAddHookMessageChannel();
register('import-in-the-middle/hook.mjs', import.meta.url, registerOptions);
import { NodeSDK } from '@opentelemetry/sdk-node';
import { registerInstrumentations } from '@opentelemetry/instrumentation';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { AlwaysOnSampler } from '@opentelemetry/sdk-trace-base';
import { SimpleLogRecordProcessor, BatchLogRecordProcessor, ConsoleLogRecordExporter } from '@opentelemetry/sdk-logs';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-grpc';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-grpc';
import { OTLPLogExporter } from '@opentelemetry/exporter-logs-otlp-grpc';
import { HttpInstrumentation } from '@opentelemetry/instrumentation-http';
import { PgInstrumentation } from '@opentelemetry/instrumentation-pg';
import { WinstonInstrumentation } from '@opentelemetry/instrumentation-winston';

// Initialize OpenTelemetry SDK
const sdk = new NodeSDK({
  sampler: new AlwaysOnSampler(),
  traceExporter: new OTLPTraceExporter(),
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter(),
  }),
  logRecordProcessors: [
    new SimpleLogRecordProcessor(new ConsoleLogRecordExporter()),
    new BatchLogRecordProcessor(new OTLPLogExporter()),
  ],
});

// Register Instrumentations
registerInstrumentations({
  instrumentations: [
    new HttpInstrumentation(),
    new PgInstrumentation({ enhancedDatabaseReporting: true }),
    new WinstonInstrumentation(),
  ],
});

sdk.start();
await waitForAllMessagesAcknowledged();