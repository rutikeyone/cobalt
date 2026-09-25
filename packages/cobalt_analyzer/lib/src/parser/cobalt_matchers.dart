import 'package:cobalt_analyzer/src/parser/annotation_matcher.dart';

const injectMatcher = CobaltAnnotationMatcher('CobaltInject');
const injectedMatcher = CobaltAnnotationMatcher('Injected');
const namedMatcher = CobaltAnnotationMatcher('Named');

/// Matches `@CobaltParam` on a constructor parameter.
const paramMatcher = CobaltAnnotationMatcher('CobaltParam');
const bootstrapMatcher = CobaltAnnotationMatcher('CobaltBootstrap');
const initMatcher = CobaltAnnotationMatcher('CobaltInit');
const environmentMatcher = CobaltAnnotationMatcher('CobaltEnvironment');
const scopeRootMatcher = CobaltAnnotationMatcher('CobaltScopeRoot');
const moduleMatcher = CobaltAnnotationMatcher('CobaltModule');
const decoratesMatcher = CobaltAnnotationMatcher('CobaltDecorates');
