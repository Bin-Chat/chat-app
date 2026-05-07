import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { QdrantModule } from './qdrant/qdrant.module';
import { KafkaModule } from './kafka/kafka.module';
import { RedisModule } from './redis/redis.module';
import { ModerationModule } from './moderation/moderation.module';
import { RagModule } from './rag/rag.module';
import { SearchModule } from './search/search.module';
import { SummaryModule } from './summary/summary.module';
import { TranslationModule } from './translation/translation.module';
import { RewriteModule } from './rewrite/rewrite.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    QdrantModule,
    KafkaModule,
    RedisModule,
    ModerationModule,
    RagModule,
    SearchModule,
    SummaryModule,
    TranslationModule,
    RewriteModule,
  ],
})
export class AppModule {}
